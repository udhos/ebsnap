#!/bin/bash

msg() {
	echo 1>&2 $0: $@
}

pipe_to_stderr() {
	local i=
	while read -r i; do
		msg $i
	done
}

filters='Name=tag:group,Values=ccc'
[ -z "$FILTERS" ] || filters="$FILTERS"

[ -n "$NO_DRY" ] || dry=--dry-run

msg FILTERS=[$FILTERS] filters=[$filters] -- very dangerous to run without filter
msg NO_DRY=[$NO_DRY] dry=[$dry] set env var NO_DRY to disable dry run
msg FORCE_INSTANCE=[$FORCE_INSTANCE] set this env var to affect only specific instance
msg FORCE_VOLUME=[$FORCE_VOLUME] set this env var to affect only specific volume
msg NO_DIE=[$NO_DIE] set this env var to keep script running after errors -- helpful to fully test dry run
msg NO_WAIT=[$NO_WAIT] set this env var to skip waiting for stopped instances -- helpful to fully test dry run

[[ -z "${filters// }" ]] && { msg refusing to run with empty filters=[$filters]; exit 2; }

instances=$(mktemp)
status=$(mktemp)
volumes=$(mktemp)

cleanup() {
	rm -f "$instances" "$status" "$volumes"
}

die() {
        msg $@
	if [ -z "$NO_DIE" ]; then
		cleanup
        	exit 1
	fi
}

msg discovering instances
aws ec2 describe-instances --filters "$filters" | jq -r '.Reservations[].Instances[].InstanceId' > $instances || die could not find instances

[ -z "$FORCE_INSTANCE" ] || echo $FORCE_INSTANCE > $instances

num_instances=$(wc -l $instances | awk '{ print $1 }')
msg found num_instances=$num_instances

cat $instances | pipe_to_stderr

msg stopping num_instances=$num_instances instances
aws ec2 stop-instances $dry --instance-ids $(cat $instances) || die could not stop instances

num_stopped=0

while [ $num_stopped -ne $num_instances ] && [ -z "$NO_WAIT" ]; do
	aws ec2 describe-instances --filters "$filters" | jq -r '.Reservations[].Instances[] | .InstanceId + " " + .State.Name' > $status || die could not get instances status
	num_stopped=$(grep stopped $status | wc -l | awk '{ print $1 }')
	msg $(date) num_stopped=$num_stopped num_instances=$num_instances
	sleep 2
done

msg discovering volumes
aws ec2 describe-instances --filters "$filters" | jq -r '.Reservations[].Instances[].BlockDeviceMappings[].Ebs.VolumeId' > $volumes || die could not find volumes

[ -z "$FORCE_VOLUME" ] || echo $FORCE_VOLUME > $volumes

cat $volumes | pipe_to_stderr

msg creating snapshots

cat $volumes | while read i; do
	volname=$(aws ec2 describe-volumes --volume-ids $i | jq -r '.Volumes[].Tags[] | select(.Key=="Name") .Value')
	msg $i $volname
	aws ec2 create-snapshot $dry --volume-id $i --description "$volname backup esmarques" --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=$volname},{Key=group,Value=ccc}]" || die could not create snapshot for volume $i
done

msg restarting instances

aws ec2 start-instances $dry --instance-ids $(cat $instances) || die could not start instances

cleanup


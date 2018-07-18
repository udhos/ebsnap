#!/bin/bash

msg() {
	echo 1>&2 $0: $@
}

filters='Name=tag:group,Values=ccc'

[ -n "$NO_DRY" ] || dry=--dry-run

msg NO_DRY=[$NO_DRY] dry=[$dry]

instances=$(mktemp)
status=$(mktemp)
volumes=$(mktemp)

cleanup() {
	rm -f "$instances" "$status" "$volumes"
}

die() {
        msg $@
	cleanup
        exit 1
}

aws ec2 describe-instances --filters "$filters" | jq -r '.Reservations[].Instances[].InstanceId' > $instances || die could not find instances

msg FORCE_INSTANCE=[$FORCE_INSTANCE]
[ -z "$FORCE_INSTANCE" ] || echo $FORCE_INSTANCE > $instances

num_instances=$(wc -l $instances | awk '{ print $1 }')
msg num_instances=$num_instances

cat $instances

aws ec2 stop-instances $dry --instance-ids $(cat $instances) || die could not stop instances

num_stopped=0

while [ $num_stopped -ne $num_instances ]; do
	aws ec2 describe-instances --filters "$filters" | jq -r '.Reservations[].Instances[] | .InstanceId + " " + .State.Name' > $status || die could not get instances status
	num_stopped=$(grep stopped $status | wc -l | awk '{ print $1 }')
	msg $(date) num_stopped=$num_stopped num_instances=$num_instances
	sleep 2
done

aws ec2 describe-instances --filters "$filters" | jq -r '.Reservations[].Instances[].BlockDeviceMappings[].Ebs.VolumeId' > $volumes || die could not find volumes

msg FORCE_VOLUME=[$FORCE_VOLUME]
[ -z "$FORCE_VOLUME" ] || echo $FORCE_VOLUME > $volumes

cat $volumes

cat $volumes | while read i; do
	volname=$(aws ec2 describe-volumes --volume-ids $i | jq -r '.Volumes[].Tags[] | select(.Key=="Name") .Value')
	msg $i $volname
	aws ec2 create-snapshot $dry --volume-id $i --description "$volname backup esmarques" --tag-specifications "ResourceType=snapshot,Tags=[{Key=Name,Value=$volname},{Key=group,Value=ccc}]" || die could not create snapshot for volume $i
done

cat $instances

aws ec2 start-instances $dry --instance-ids $(cat $instances) || die could not start instances

cleanup


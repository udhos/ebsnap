# ebsnap

## Usage

Run the script to get list of env vars available for customization:

    $ ./ebsnap.sh
    ./ebsnap.sh: refusing KEEP=[] lower than 3
    ./ebsnap.sh: FILTERS=[] filters=[Name=tag:group,Values=ccc] -- very dangerous to run without filter
    ./ebsnap.sh: NO_DRY=[] dry=[--dry-run] set env var NO_DRY to disable dry run
    ./ebsnap.sh: FORCE_INSTANCE=[] set this env var to affect only specific instance
    ./ebsnap.sh: FORCE_VOLUME=[] set this env var to affect only specific volume
    ./ebsnap.sh: NO_DIE=[] set this env var to keep script running after errors -- helpful to fully test dry run
    ./ebsnap.sh: NO_WAIT=[] set this env var to skip waiting for stopped instances -- helpful to fully test dry run
    ./ebsnap.sh: KEEP=[] keep=[2] keep at most keep=2 snapshots per volume. Delete older snapshots.


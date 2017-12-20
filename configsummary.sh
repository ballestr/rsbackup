#!/bin/bash
# synoptic summary of configurations
for par in snapshot_root logfile loglevel link_dest sync_first no_create_root interval ssh_args exclude_file rsync_short_args rsync_long_args; do
    for cfg in etc/rsnapshot.*.conf; do
    printf "%-50s:" $cfg
    grep  "^$par" $cfg || echo "$par (not found)"
    done
done

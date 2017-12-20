#!/bin/bash
DIR=/opt/rsbak

## Do all backups first
for cfg in $@ ; do
    $DIR/bin/rsbackup.sh $DIR/etc/rsnapshot.$cfg.conf
done
## Do all rotations after
for cfg in $@ ; do
    $DIR/bin/rsbackup.sh $DIR/etc/rsnapshot.$cfg.conf
done

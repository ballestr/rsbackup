#!/bin/bash
DIR=/opt/rsbak
for cfg in $@ ; do
    $DIR/bin/rsbackrotate.sh $DIR/etc/rsnapshot.$cfg.conf
done

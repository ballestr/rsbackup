#!/opt/bin/bash
## write a status report file for a backup done by a remote host
. /opt/rsbak/etc/rsbackup.rc || exit 1

#echo $@
#set

CFGB=$1
status=$2
[ "$CFGB" ] || exit 1
printf "%-4s %s\n" "$status"  "$(date '+%Y-%m-%d %H:%M') $CFGB [Remote $SSH_CLIENT]" >$LOGDIR/$CFGB.status

#!/opt/bin/bash
## write a status report file for a backup done by a remote host
. /opt/rsbak/etc/rsbackup.rc || exit 1

#echo $@
#set

CFGB=$1
status=$2
[ "$CFGB" ] || exit 1
if [ "$CFGB" = "configtest" ] ; then
    which nice >/dev/null || echo "nice not found"
    which ionice >/dev/null || echo "ionice not found"
    which rsync >/dev/null || echo "rsync not found"
    echo "rsbackreport.sh $CFGB from $SSH_CLIENT OK $(date '+%Y-%m-%d %H:%M')"
    exit 0
else
    printf "%-4s %s\n" "$status"  "$(date '+%Y-%m-%d %H:%M') $CFGB [Remote $SSH_CLIENT]" >$LOGDIR/$CFGB.status
fi

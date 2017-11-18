#!/opt/bin/bash
## Backups using rsnapshot
## with nice e-mails even on Synology ;-)
## Sergio Ballestrero, Jan 2017

. /opt/rsbak/etc/rsbak.rc || exit 1
LOG=/var/log/rsbackup.log
##--- end config

if [ -z "$1" ] ; then 
  echo "$(basename $0): please specify config param"
  exit 1
fi

mkdir -p $LOGDIR || exit 1
BODY=$(mktemp /var/tmp/rsbackup.mailbody.XXXXXXXXXXX)
[ -f $BODY ] || exit 1

R=0
CFG=$1
CFGB=$(basename $1 .conf)
if ! [ -r "$CFG" ] ; then
  if [ -t 1 ]; then
    ## interactive, fail immediately
    echo "$(basename $0): config file $CFG not found"
    rm -f $BODY
    exit 1
  else
    /usr/bin/logger -t rsbackup -p user.warn "missing config file $CFG"
    echo "FAIL $CFGB $(date '+%Y-%m-%d %H:%M') res=noconfig">$LOGDIR/$CFGB.status
    echo "$(date) config file $CFG not found" > $BODY
    R=1
  fi
fi

## be nice
renice 10 -p $$ >/dev/null

if [ $R -eq 0 ]; then
  /usr/bin/logger -t rsbackup -p user.warn "start rsnapshot $CFGB sync"
  echo "$(date) start rsbackup $CFG" > $BODY
  rsnapshot -c $CFG sync >> $BODY 2>&1
  R=$?
  echo "$(date) sync $CFG done R=$R" >> $BODY
  echo "$(date) sync $CFG done R=$R" >> $LOG
  /usr/bin/logger -t rsbackup -p user.warn "done rsnapshot $CFGB sync res=$R"

  [ $R -eq 0 ] && rsnapshot -c $CFG hourly >> $BODY 2>&1

  date >> $BODY
  DIR=$(egrep "^snapshot_root" $CFG | awk '{print $2}') 2>/dev/null
  [ "$DIR" ] && ls -lat $DIR/ 2>&1 >> $BODY
fi

if [ $R -ne 0 ] ; then
  status="FAIL"
else
  status="OK  "
fi
echo "$status $(date '+%Y-%m-%d %H:%M') $CFGB">$LOGDIR/$CFGB.status
# report result to remote hosts
for host in $(egrep "^backup.*@" $CFG | sed 's/.*\t\(.*\):.*/\1/' | uniq) ; do #'confusedmc
   ssh $host "rsbackreport.sh $HOSTNAME:$CFGB $status " 2>&1 >>$BODY
done

if [ $R -ne 0 ] ; then
  (
  echo -e "From: $FROM\nTo: $MAILTO\nSubject: [RSBAK/$HOST] $CFGB hourly $status \n\n"
  cat $BODY
  ) | /usr/sbin/sendmail $MAILTO >$LOGDIR/rsbackup_mail.out 2>&1
  if [ "$SYNOBEEP" ]; then
    ## beep Synology for 15 seconds
    ## https://forum.synology.com/enu/viewtopic.php?t=45213
    for a in $(seq 1 15); do
      echo 3 >/dev/ttyS1
      sleep 1
    done
  fi
fi
rm $BODY

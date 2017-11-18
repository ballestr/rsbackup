#!/opt/bin/bash
## send status mail for rsbak
## Sergio.Ballestero@gmail.com January 2017

. /opt/rsbak/etc/rsbak.rc || exit 1

## add to cron path
PATH="/usr/sbin:/sbin:$PATH"

function rsback_status {
status="OK"
if grep -q FAIL $LOGDIR/*.status ; then
    status="FAIL"
fi
stale=$(find $LOGDIR -name "*.status" -mmin +$[60*$FRESHMAX+60])
if [ "$stale" ]; then
    status="STALE $status"
fi
stalelog=$(find $LOGDIR -name "*.log" -mmin +$[60*$FRESHMAX+60])
if [ "$stalelog" ]; then
    status="STALELOG $status"
fi

logger -t rsbackup -p user.warn "status check $STATUS"

## Mail headers
[ "$1" = "-m" ] && echo -e "From: $FROM\nTo: $MAILTO\nSubject: [RSBAK/$HOST] status $status\n"

echo "$(date) Checking status files in $HOST:$LOGDIR : $status"
if [ "${stale}${stalelog}" ]; then
    echo
    echo "** ERROR: Stale status/log files found (>$FRESHMAX hours):"
    for f in $stale $stalelog; do
      ls -la $f
      cat $f
    done
    echo "**"
    echo
fi
echo "** Status files content:"
cat $LOGDIR/*.status
if [ "$DEBUG" ]; then
  echo
  echo "** DEBUG: Files in $LOGDIR:"
  (cd $LOGDIR && ls -la *.status)
fi
}

if [ "$1" = "-m" ]; then
  rsback_status -m  2>&1 | sendmail $MAILTO
else
  rsback_status
fi

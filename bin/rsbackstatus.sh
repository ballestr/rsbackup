#!/opt/bin/bash
## send status mail for rsbak
## Sergio.Ballestero@gmail.com January 2017
## support exit codes etc for nagios/icinga servicecheck
## Sergio.Ballestero@gmail.com December 2017

. /opt/rsbak/etc/rsbackup.rc || exit 1

## add to cron path
PATH="/usr/sbin:/sbin:$PATH"

function rsback_status() {
    local MODE=$1
    local status="OK"
    local level="notice"
    shopt -s nullglob
    local F="$(find $LOGDIR -name '*.status')" # using find seems the only reliable way
    if [ "$F" ] ; then
        if grep -q FAIL $F ; then
            status="FAIL"
        fi
    else
        status="NOSTATUS"
    fi
    stale=$(find $LOGDIR -name "*.status" -mmin +$[60*$FRESHMAX+60])
    if [ "$stale" ]; then
        status="STALE $status"
    fi
    stalelog=$(find $LOGDIR -name "*.log" -mmin +$[60*$FRESHMAX+60])
    if [ "$stalelog" ]; then
        status="STALELOG $status"
    fi
    [ "$status" = "OK" ] || level="error"
    logger -t rsbackup -p user.$level "status check $STATUS"

    ## Mail headers
    [ "$MODE" = "--mail" ] && echo -e "From: $FROM\nTo: $MAILTO\nSubject: [RSBAK/$HOST] status $status\n"

    if [ "$MODE" = "--nagios" ]; then
        echo "$status rsbackup $HOST:$LOGDIR :"
    else
        echo "$(date) Checking status files in $HOST:$LOGDIR : $status"
    fi
    if [ "${stale}${stalelog}" ]; then
        echo
        echo "** ERROR: Stale status/log files found (>$FRESHMAX hours):"
        for f in $stale $stalelog; do
            ls -la $f
            tail -n5 $f
        done
        echo "**"
        echo
    fi
    echo "** Status files content:"
    ls $LOGDIR/*.status >/dev/null  && cat $LOGDIR/*.status
    if [ "$MODE" = "--nagios" ]; then
        [ "$status" = "OK" ] || return 1
        return 0
    fi
    if [ "$DEBUG" ]; then
        echo
        echo "** DEBUG: Files in $LOGDIR:"
        (cd $LOGDIR && ls -la *.status)
    fi
}

if [ "$1" = "-m" -o "$1" = "--mail" ]; then
    rsback_status --mail  2>&1 | sendmail $MAILTO
else
    rsback_status $1
fi

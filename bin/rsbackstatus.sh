#!/opt/bin/bash
## send status mail for rsbak
## Sergio.Ballestero@gmail.com January 2017
## support exit codes etc for nagios/icinga servicecheck
## Sergio.Ballestero@gmail.com December 2017

. /opt/rsbak/etc/rsbackup.rc || exit 1

export LANG=C ## avoid funny stuff with sorting

## add to cron path
PATH="/usr/sbin:/sbin:$PATH"

function rsback_status() {
    status="OK"
    local MODE=$1
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
    local F2="$(find $LOGDIR -name '*.status' -a -not -name '@*' -a -not -name '*.rotate.status')"
    for f in $F2; do
        strot="$LOGDIR/$(basename $f .status).rotate.status"
        if ! [ -f "$strot" ] ; then
            status="NOROT $status"
            break
        fi
    done

    [ "$status" = "OK" ] || level="error"
    logger -t rsbackup -p user.$level "status check $STATUS"

    ## Mail headers
    [ "$MODE" = "--mail" ] && echo -e "From: $FROM\nTo: $MAILTO\nSubject: [RSBAK/$HOST] status $status\n"

    if [ "$MODE" = "--nagios" ]; then
        echo "$status rsbackup $HOST:$LOGDIR :"
    else
        echo "$(date) Checking status files in $HOST:$LOGDIR : $status"
    fi
    for f in $F2; do
        strot="$LOGDIR/$(basename $f .status).rotate.status"
        if ! [ -f "$strot" ] ; then
            echo "** ERROR: not found matching $strot"
        fi
    done
    if [ "${stale}${stalelog}" ]; then
        echo
        echo "** ERROR: Stale status/log files found (>$FRESHMAX hours) in $LOGDIR :"
        for f in $stale $stalelog; do
            echo "** $(basename $f) :" # $(stat --format='%z' $f)"
            ls -la $f | sed 's/^/  # /'
            tail -n5 $f | sed 's/^/  /'
        done
        echo "**"
        echo
    fi
    echo "** Status files content:"
    ls $LOGDIR/*.status >/dev/null  && cat $(ls $LOGDIR/*.status) ## ls to sort
    if [ "$MODE" = "--nagios" ]; then
        [ "$status" = "OK" ] || return 1
        return 0
    fi
    if [ "$DEBUG" ]; then
        echo
        echo "** DEBUG: Files in $LOGDIR by date:"
        (cd $LOGDIR && ls -lat *.status)
    fi
}

declare status
if [ "$1" = "-m" -o "$1" = "--mail" -o "$1" = "--mailerr" ]; then
    mailfile=$(mktemp /var/tmp/rsbackstatus.XXXXXXXX)
    rsback_status --mail  2>&1 > $mailfile
    if [ $1 != "--mailerr" -o "$status" != "OK" ]; then
        cat $mailfile | sendmail $MAILTO
        [ -t 0 ] && echo "status='$status', mail sent to $MAILTO"
    else
        [ -t 0 ] && echo "status='$status', mail not sent to $MAILTO"
    fi
    rm -f $mailfile
else
    rsback_status $1
fi

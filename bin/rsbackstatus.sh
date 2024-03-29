#!/bin/bash
## send status mail for rsbak
## Sergio.Ballestero@gmail.com January 2017
## support exit codes etc for nagios/icinga servicecheck
## Sergio.Ballestero@gmail.com December 2017

. /opt/rsbak/etc/rsbackup.rc || exit 1

export LANG=C ## avoid funny stuff with sorting

## add to cron path
PATH="/usr/sbin:/sbin:$PATH"

function rsback_status() {
    status="OK" ## status is global
    local MODE=$1
    local level="notice"
    local checkstatus
    #shopt -s nullglob

    ## Note that wanting to have a summary status for the mail subject
    ## led to some code duplications. This function probably should be rearranged overall.

    local F="$(find $LOGDIR -name '*.status')" # using find seems the only reliable way
    if [ "$F" ] ; then
        if grep -q FAIL $F ; then
            status="FAIL"
            checkstatus=2
        elif grep -q WAIT $F ; then
            status="WAIT"
        else
            status="OK"
        fi
    else
        status="NOBACKUP"
        checkstatus=2
    fi

    ## Check for stale status files and logs
    stale=$(find $LOGDIR -name "*.status" -mmin +$[60*$FRESHMAX+60])
    if [ "$stale" ]; then
        if grep -q WAIT $F ; then
            status="BADRETAIN $status"
            checkstatus=2
        fi
        status="STALE $status"
    fi
    stalelog=$(find $LOGDIR -name "*.log" -mmin +$[60*$FRESHMAX+60])
    if [ "$stalelog" ]; then
        status="STALELOG $status"
    fi

    ## check for each rsnapshot status to have a corresponding rotation status
    local F2="$(find $LOGDIR -name '*.status' -a -not -name '@*' -a -not -name '*.rotate.status')"
    for f in $F2; do
        strot="$LOGDIR/$(basename $f .status).rotate.status"
        if ! [ -f "$strot" ] ; then
            status="NOROTATION $status"
            checkstatus=2
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

    if [[ "$status" =~ "NOBACKUP" ]]; then
        echo "** ERROR: No backup status files found. Check your backup configuration (local or server pull)."
        echo "-- local rsnapshot config files:"
        ls -la /opt/rsbak/etc/rsnapshot*.conf 2>&1
        echo "-- Contents of $LOGDIR:"
        ls -la $LOGDIR 2>&1
    fi
    ## explain STALE status
    if [[ "$status" =~ "STALE" ]]; then
        echo "** ERROR: Stale status/log files found, some backups have not been done in more than $FRESHMAX hours."
    fi
    ## report for each rsnapshot status to have a corresponding rotation status
    for f in $F2; do
        strot="$LOGDIR/$(basename $f .status).rotate.status"
        if ! [ -f "$strot" ] ; then
            echo "** ERROR: not found matching $(basename $strot) for $(basename $f)"
        fi
    done
    ## explain BADRETAIN status
    if [[ "$status" =~ "BADRETAIN" ]]; then
        echo "** ERROR: Stale WAIT status found, most probably incorrect configuration of rsnapshot retain number"
    fi
    ## explain WAIT status
    if [[ "$status" =~ "WAIT" ]]; then
        echo "** WARNING: WAIT status found, one or more backups did not have the first rotation in <$FRESHMAX hours."
        echo "   Note: this will become an error if rotation does not happen within $FRESHMAX hours from WAIT timestamp."
    fi

    ## report statuses
    echo
    if [ "${stale}${stalelog}" ]; then
        echo "** STALE status/log files content :"
        for f in $stale $stalelog; do
            echo "** $(basename $f) :" # $(stat --format='%z' $f)"
            ls -la $f | sed 's/^/  # /'
            tail -n5 $f | sed 's/^/  /'
        done
        #echo ""
    fi
    echo "-- Status files content:"
    ls $LOGDIR/*.status >/dev/null 2>&1 && cat $(ls $LOGDIR/*.status) ## ls to sort

    ## return code for nagios servicecheck
    if [ "$MODE" = "--nagios" ]; then
        [ "$checkstatus" ] && return $checkstatus
        [ "$status" = "OK" ] || return 1
        return 0
    fi
    if [ "$DEBUG" ]; then
        echo
        echo "-- DEBUG: Status files in $LOGDIR by date:"
        (cd $LOGDIR && ls -lat *.status 2>&1)
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

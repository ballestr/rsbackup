#!/opt/bin/bash
## rotate rsnapshot backups with name-is-date
## sergio.ballestrero@gmail.com, 2011
## sergio.ballestrero@gmail.com, Jan 2017
##
. /opt/rsbak/etc/rsbackup.rc || exit 1
[ "$MAXWAIT" ] || MAXWAIT=5 ## default max 5 minutes waiting for lock


if ! [ -f "$1" ] ; then
  echo "$0: config file '$1' not found"
  exit 1
fi

BODY=$(mktemp /var/tmp/rsbackrotate.mailbody.XXXXXXXXXX)
CONF=${1}
CFGB=$(basename $CONF .conf)
DIR=$(egrep "^snapshot_root" $CONF | awk '{print $2}')
LOCK=$(egrep "^lockfile" $CONF | awk '{print $2}')



mkdir -p $LOGDIR
LOG=$LOGDIR/$CFGB.rotate.log


echo "$(date -Iseconds) Start rsbackup rotate $CFGB" | tee -a $LOG >> $BODY
echo "  CONF=$CONF" >> $BODY
echo "  DIR =$DIR"  >> $BODY
echo "  LOCK=$LOCK" >> $BODY
TODAY=$(date +%Y-%m-%d)
[ "$DIR" ] || { echo "## $CFGB : empty snapshot_root"; exit 1; }
[ "$LOCK" ] || { echo "## $CFGB : empty lockfile"; exit 1; }

# ls -ldt $DIR/hourly.* >> $LOG ## DEBUG

CHANGES=0
CHANGESday=0

if [ -f "$LOCK" ]; then
    echo "$(date -Iseconds) wait max $MAXWAIT min on $LOCK" | tee -a $LOG >> $BODY
    while [ -f "$LOCK" ]; do
        [ -t 0 ] && echo "$(date -Iseconds) wait $MAXWAIT found lockfile $LOCK ='$(<$LOCK)' $(ls -l $LOCK)"
        sleep 60
        MAXWAIT=$[MAXWAIT-1]
        [ $MAXWAIT -gt 0 ] || break
    done
    if ! [ -f "$LOCK" ]; then
        echo "$(date -Iseconds) done wait on $LOCK" | tee -a $LOG >> $BODY
    fi
fi

## Check that we have some reasonably-recent backup
T=2
if ! [ -d $DIR ]; then
    echo "  ALERT: $DIR missing" | tee -a $LOG >> $BODY
    CHANGES=999
elif ! find $DIR -maxdepth 1 -mtime -${T} -name "hourly*" >/dev/null 2>&1 ; then
    echo "  ALERT: no valid backup in the last $T days !!" | tee -a $LOG >> $BODY
    CHANGES=999
fi

function rotate_hourly {
## First, copy any new hourly backup if there is not a corrisponding daily
## go through them, most recent first, to try to get the latest one from yesterday
for HOURLY in $(ls -dt $DIR/hourly.* 2>/dev/null); do
#for HOURLY in $(ls -dt $DIR/hourly.* $DIR/daily.* $DIR/weekly.* $DIR/monthly.*); do
    HDATE=$(date -r $HOURLY +"%Y-%m-%d")
    ## Skip today
    [ "$HDATE" = "$TODAY" ] && continue
    weekday=$(date -r $HOURLY +%W_%u)
    daily="auto_${HDATE}_daily_${weekday}"
    ## nothing to do if it's present already
    [ -d $DIR/$daily ] && continue
    echo "  Making $daily from $(basename $HOURLY)" | tee -a $LOG >> $BODY
    #mkdir $DIR/$daily
    #touch -r $HOURLY $DIR/$daily
    cp -al $HOURLY $DIR/$daily
    CHANGESday=$[CHANGESday+1] # do not report this
done
}

function rotate_weekly {
## Now get one per week
thisweek=$(date +%W)
for D in $(ls -dt $DIR/auto_*_daily_* 2>/dev/null); do
    daily=$(basename $D)
    week=$(echo $daily|cut -d_ -f4)
    year=$(echo $daily|sed -e "s/^.*_\(....\)-..-.._.*/\1/") #"confusedmc
    ## skip if current week
    [ "$week" = "$thisweek" ] && continue
    ## check if there's already this year and week
    [ -d $DIR/auto_${year}-*_weekly_${week} ] && continue
    weekly=$(echo $daily | sed -e "s/_daily_\(..\)_./_weekly_\1/") #"confusedmc
    echo "  Making $weekly from $daily" | tee -a $LOG >> $BODY
    cp -al $D $DIR/$weekly
    #echo rm $D
    CHANGES=$[CHANGES+1]
done
}

function rotate_monthly {
## Now get one per month
thisyear=$(date +%Y)
thismonth=$(date +%m)
for D in $(ls -dt $DIR/auto_*_weekly_* 2>/dev/null); do
    weekly=$(basename $D)
    month=$(echo $weekly|sed -e "s/^.*_....-\(..\)-.._.*/\1/") #"confusedmc
    year=$(echo $weekly|sed -e "s/^.*_\(....\)-..-.._.*/\1/") #"confusedmc
    ## skip if current year and month
    [ "$year" = "$thisyear" -a "$month" = "$thismonth" ] && continue
    ## check if there's already this year and month
    [ -d $DIR/auto_${year}-${month}-*_monthly ] && continue
    monthly=$(echo $weekly | sed -e "s/_weekly_../_monthly/")
    echo "  Making $monthly from $weekly" | tee -a $LOG >> $BODY
    cp -al $D $DIR/$monthly
    #echo rm $D
    CHANGES=$[CHANGES+1]
done
}
## Cleanup of old copies
function rotate_cleanup() {
#set +x
## Cleanup daily directories 
## only if there is a more recent weekly
recentWeekly=$(find $DIR/auto_*_weekly_* -maxdepth 0 -mtime -$OLD_DAILY 2>/dev/null)
if [ "$recentWeekly" ] ; then
for OLD in $(find $DIR/auto_*_daily_* -maxdepth 0 -mtime +$OLD_DAILY 2>/dev/null); do
    d=$(basename $OLD)
    ## Paranoid sanity check, only remove "auto" directories
    [ "$(echo $d|cut -d_ -f1)" = "auto" ] || continue
    echo "  Removing $d" | tee -a $LOG >> $BODY
    rm -rf $OLD
    CHANGESday=$[CHANGESday+1]
done
fi

DELETED=0
## Cleanup weekly directories 
## only if there is a more recent monthly
recentMonthly=$(find $DIR/auto_*_monthly_* -maxdepth 0 -mtime -$OLD_WEEKLY 2>/dev/null)
if [ "$recentMonthly" ] ; then
for OLD in $(find $DIR/auto_*_weekly_* -maxdepth 0 -mtime +$OLD_WEEKLY 2>/dev/null); do
    d=$(basename $OLD)
    ## Paranoid sanity check, only remove "auto" directories
    [ "$(echo $d|cut -d_ -f1)" = "auto" ] || continue
    echo "  Removing $d" | tee -a $LOG >> $BODY
    rm -rf $OLD
    CHANGES=$[CHANGES+1]
    ## sanity check: do not delete more than two weekly at a time
    ## just in case the system date has gone crazy
    DELETED=$[DELETED+1]
    if [ $DELETED -gt 2 ]; then
        break
    fi
done
fi

## no cleanup for monthly... if you care about your backups you can look at them once a year ;-)
}

if [ -f $LOCK ]; then
    ## do not touch the hourly if rsnapshot is running
    echo "  ALERT: skipping hourly, still running $LOCK ='$(<$LOCK)' $(ls -l $LOCK) " | tee -a $LOG >> $BODY
    CHANGES=999
    rotate_hourly
fi
rotate_weekly
rotate_monthly
rotate_cleanup

echo "$(date -Iseconds) done. CHANGES=$CHANGES CHANGESday=$CHANGESday" | tee -a $LOG >> $BODY

logger -t rsbackup -p user.warn "rotate $CHANGES $CHANGESday"

## write a status file if anything has been touched
STF="$LOGDIR/$CFGB.rotate.status"
if [ $CHANGES -gt 0 -o $CHANGESday -gt 0 ] ; then
    if [ $CHANGES -eq 999 ] ; then ST="FAIL"; else ST="OK  "; fi
    echo "$ST $(date +'%Y-%m-%d %H:%M') $CFGB rotate changes $CHANGES/$CHANGESday in $DIR" > $STF
fi
## if there is no status file, create one so it can go stale if no rotation is done
if ! [ -f $STF ]; then
    echo "WAIT $(date +'%Y-%m-%d %H:%M') $CFGB rotate waiting for first HOURLY in $DIR" > $STF
fi

## report if there is any change except adding/removing a daily
if [ $CHANGES -eq 999 ] ; then ST="FAIL"; else ST="OK $CHANGES changes"; fi
if [ $CHANGES -gt 0 -o $CHANGESday -gt 2 ] ; then
  echo -e "\n\n----------------------------------------" >> $BODY
  if [ -d $DIR ] ; then
    df -hP $DIR 2>&1 >> $BODY
    ls -latd $DIR/auto* 2>&1 >> $BODY
  fi
  if [ -t 0 ]; then
    echo "[RSBAK/$HOST] rotate $CFGB $ST"
    cat $BODY
  else
    (
      echo -e "From: $FROM\nTo: $MAILTO"
      echo -e "Subject: [RSBAK/$HOST] rotate $CFGB $ST\n\n"
      cat $BODY
    ) | /usr/sbin/sendmail $MAILTO >$LOGDIR/$CFGB.rotatemail.out 2>&1
  fi
else
  if [ -t 0 ]; then
    echo "[RSBAK/$HOST] rotate $CFGB $ST"
    cat $BODY
  fi
fi

rm $BODY

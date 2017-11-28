#!/opt/bin/bash
## quick-and-dirty setup script
## assume that rsbackup has been checked-out unders /opt/rsbak
## setup crontab 
## create link to host-specific /opt/rsbak/etc.<hostname> directory

## [ -d /opt/etc ] || exit 1 # check for Synology? no...

#ls -la /opt/rsbak || exit
cd /opt/rsbak || exit

[ -d etc ] || { echo "## configtest: no etc configuration directory"; exit 1; }
[ -f etc/rsbackup.rc ] || { echo "## configtest: no etc/rsbackup.rc file"; exit 1; }

R=0
N=0
shopt -s nullglob
for cfg in etc/rsnapshot.*.conf; do
    echo -n "## Checking $(basename $cfg):  "
    rsnapshot -v -c $cfg configtest
    r=$?
    R=$[R+r]
    N=$[N+1]
done

if [ $N -eq 0 ]; then
    echo "## configtest: no rsnapshot config, client only OK"
    exit 0
fi

RSA=/root/.ssh/id_rsa_rsbackup
if ! [ -f $RSA ] ; then
    echo "missing $RSA"
    R=$[R+1]
fi

if [ -d /etc/cron.d ]; then
  cronfile="/etc/cron.d/rsbackup_cron"
  if ! [ -f $cronfile ] ; then
     echo "Missing crontab file $cronfile"
     R=$[R+1]
  fi
else
  grep "/opt/rsbak" /etc/crontab > .tmp_crontab.rsbak
  if ! diff -s etc/rsbak.cron .tmp_crontab.rsbak ; then
    echo "* /etc/crontab out of sync"
    R=$[R+1]
    #echo "# updating /etc/crontab"
    #echo "# cp crontab /etc/crontab; killall -s HUP crond"
    #cp /etc/crontab /etc/crontab.bak.$(date +%Y%m%d%H%M)
    #grep -v "/opt/rsbak" /etc/crontab > .tmp_crontab.clean
    #cat crontab.clean etc/rsbak.cron > /etc/crontab
    #killall -s HUP crond
  fi
fi
echo "## configtest result: $R"
exit $R
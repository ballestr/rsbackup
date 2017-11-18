#!/opt/bin/bash
## quick-and-dirty setup script
## assume that rsbackup has been checked-out unders /opt/rsbak
## setup crontab 
## create link to host-specific /opt/rsbak/etc.<hostname> directory

## [ -d /opt/etc ] || exit 1 # check for Synology? no...

ls -la /opt/rsbak || exit
cd /opt/rsbak || exit

ln -snf etc.$(hostname -s) etc
[ -d etc ] || exit

mkdir -p /var/log/rsbackup/

for cfg in etc/rsnapshot.*.conf; do
  echo -n "$(basename $cfg):  "
  rsnapshot -v -c $cfg configtest
done

RSA=/root/.ssh/id_rsa_rsbackup
if ! [ -f $RSA ] ; then
    echo "missing $RSA, generating"
    ssh-keygen -t rsa -N "" -C "rsbackup@$(hostname -s)_$(date +%Y%m%d)" -f $RSA
fi

if [ -d /etc/cron.d ]; then
  cp etc/rsbak.cron /etc/cron.d/rsbak_cron
  rm -f /etc/cron.d/rsbak.cron
else
  grep "/opt/rsbak" /etc/crontab > .tmp_crontab.rsbak
  if ! diff -s etc/rsbak.cron .tmp_crontab.rsbak ; then
    echo "# updating /etc/crontab"
    #echo "# cp crontab /etc/crontab; killall -s HUP crond"
    cp /etc/crontab /etc/crontab.bak.$(date +%Y%m%d%H%M)
    grep -v "/opt/rsbak" /etc/crontab > .tmp_crontab.clean
    cat crontab.clean etc/rsbak.cron > /etc/crontab
    killall -s HUP crond
  fi
fi

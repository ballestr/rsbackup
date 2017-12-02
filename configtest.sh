#!/opt/bin/bash
## quick-and-dirty setup script
## assume that rsbackup has been checked-out unders /opt/rsbak
## setup crontab 
## create link to host-specific /opt/rsbak/etc.<hostname> directory

## [ -d /opt/etc ] || exit 1 # check for Synology? no...

DIR=/opt/rsbak
SSHCFG=$DIR/etc/ssh.config

#ls -la /opt/rsbak || exit
cd $DIR || exit

[ -d etc ] || { echo "## configtest: no etc configuration directory"; exit 1; }
[ -f etc/rsbackup.rc ] || { echo "## configtest: no etc/rsbackup.rc file"; exit 1; }

RSA=/root/.ssh/id_rsa_rsbackup
if ! [ -f $RSA ] ; then
    echo "missing ssh key $RSA"
    R=$[R+1]
fi

R=0
N=0
shopt -s nullglob
for cfg in etc/rsnapshot.*.conf; do
    N=$[N+1]
    echo -n "## Checking $(basename $cfg):  "
    rsnapshot -v -c $cfg configtest
    r=$?
    R=$[R+r]
    DIR=$(egrep "^snapshot_root" $cfg | awk '{print $2}') 2>/dev/null
    if ! [ -d $DIR ]; then
	echo "### checking snapshot_root '$DIR' : not present or not a directory"
	R=$[R+1]
    fi
    ## check SSH
    sshdest=$(grep ^backup $cfg | grep @ | cut -f2 | cut -d: -f1 | sort | uniq)
    if [ "$sshdest" ]; then
        echo -n "### checking config $cfg for ssh_args containing '-F $SSHCFG': "
	egrep -q "^ssh_args.*-F $SSHCFG" $cfg
	if [ $? -ne 0 ]; then
	    echo "failed:"
	    egrep "ssh_args" $cfg
	    R=$[R+1]
	else
	    echo "OK"
	fi
        for sd in $sshdest; do 
	    echo "### checking SSH : ssh -F $SSHCFG $sd rsbackreport.sh configtest :"
	    ssh -F $SSHCFG $sd rsbackreport.sh configtest
	    r=$?
	    [ $r -eq 0 ] || echo "-- failed, r=$r"
	    R=$[R+r]
	done
    fi

done

if [ $N -eq 0 ]; then
    echo "## configtest: no rsnapshot config, client only OK"
    exit 0
fi

if [ -d /etc/cron.d ]; then
  cronfile="/etc/cron.d/rsbackup_status_cron"
  if ! [ -f $cronfile ] ; then
     echo "Missing crontab file $cronfile"
     R=$[R+1]
  fi
else
  ## Synology DSM only uses /etc/crontab :-(
  grep "/opt/rsbak" /etc/crontab > .tmp_crontab.rsbak
  if ! diff -s etc/rsbackup.cron .tmp_crontab.rsbak ; then
    echo "* /etc/crontab out of sync"
    R=$[R+1]
    #echo "# updating /etc/crontab"
    #echo "# cp crontab /etc/crontab; killall -s HUP crond"
    #cp /etc/crontab /etc/crontab.bak.$(date +%Y%m%d%H%M)
    #grep -v "/opt/rsbak" /etc/crontab > .tmp_crontab.clean
    #cat crontab.clean etc/rsbak.cron > /etc/crontab
    #killall -s HUP crond
  fi
  rm .tmp_crontab.rsbak
fi
echo "## configtest result: $R"
exit $R

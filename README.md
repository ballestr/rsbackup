# rsbackup
Wrapper/helper scripts etc for rsnapshot, with explicit date-based naming and rotation.
* http://rsnapshot.org/
* https://github.com/rsnapshot/rsnapshot

## Related repos
* https://github.com/ballestr/puppet-rsbackup

## Pull mode backups
Doing backups in "pull mode" (where the server initiates the connection to a "target" client) has advantages for security.
In practice, since the target "client" does not have any credentials to access the backup location, 
a compromise of the client does not create (almost) any risk for the backup. 
The "almost" is only because the intruder may notice configurations and logs identifying the backup server and decide to target it too.

The downside of pull mode are that 
* it's the server that decides when to do the backup, so it's quite difficult to avoid high-load periods
* the backup is not accessible from the client, and the server is restricted from pushing files back to the client,
  so retrieving files is more difficult. 
  If this is a concern then it's suggested to have a local rsbackup.

In summary, this kind of backup is recommended when:
* the "targets" are more exposed than the backup host
* you want to centralise the backup configuration (what to backup and when) on the central host

## Install on target
The "target" host (from which the backup is pulled by the server) needs to have installed:
* `ssh`
* `rsync`
* `nice` (`coreutils-nice` on opkg)
* `ionice`

For security, the `/root/.ssh/authorized_keys` must include a forced command, associated with the dedicated rsbackup public key on the server:
```
command="/opt/rsbak/bin/validate_rsync" ssh-rsa <hash_here> rsbackup@server
```
so you need to copy the `validate_rsync` script on the target host too. 
If you also want daily status reports from the target host (recommended) it's necessary to install the whole `/opt/rsback`. 

## Install on server
The easiest installation is to simply clone this repo to the standard location: 
```
git clone https://github.com/ballestr/rsbackup.git /opt/rsbak`
```
then create `/opt/rsbak/etc` starting from the examples provided, and add the commands in a crontab following the example.

For non-local backups, you should add an entry for each target host in the `/opt/rsbak/etc/ssh.config`, and give it a special hostname like `rsb.mytargethost`.  
This is helpful not only for enforcing use of the dedicated key and other custom parameters, but also for not having to change rsbackup configurations
if the DNS name changes, e.g. because you have to switch from one DynamicDNS provider to another.
```
Host rsb.hostname1
    # HostName oldhostname1.dyndns.org
    HostName hostname1.somedomain.me
    # Port 2045 # custom remapped port
    Compression yes
    User root
    BatchMode yes
    IdentityFile ~/.ssh/id_rsa_rsbackup
```

On the server, you need to install the following packages, in addition to `rsbackup` :
* `ssh`
* `rsync`
* `rsnapshot`
* `nice` (`coreutils-nice` on opkg)
* `mktemp` (`coreutils-mktemp` on opkg)
* `ionice`

For the rest, rsbackup uses the normal configuration files of rsnapshot; the setting for using the custom SSH config must be given explicitly:
```
ssh_args	-F /opt/rsbak/etc/ssh.config
```

The `install.sh` script helps in the setup, especially with merging the `/etc/crontab` on Synology DSM 5. The Puppet module or the Ansible task (in preparation) are recommended.

The `configcheck.sh` script helps spotting typical configuration issues.

## `bash` on Synology and other Linuxes
Note that the shell scripts here use `/opt/bin/bash`, for compatibility with Synology Linux with opkg or similar.  
If you're using this on a standard linux you'll have to change shebang or add a `/opt/bin/bash -> /bin/bash` symlink.
Unfortunately adding a `/bin/bash -> /opt/bin/bash` on Synology triggers the security alerts, so that is no-go.

## ToDo:
- [x] Puppet module for server and target configuration: https://github.com/ballestr/puppet-rsbackup
- [ ] Ansible role for server and target configuration
- [ ] Use a more restrictive sudo on the target side instead of root login.
- [ ] Unify status and rotate report emails
- [ ] Provide a nagios/icinga check script, or add the functionality in `rsbackstatus.sh`
- [ ] Let `rsbackup.sh` run multiple rsnapshot configurations, to simplify crontabs
- [ ] `rsbackrotate.sh` should check the lock file


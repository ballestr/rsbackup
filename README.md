# rsbackup
Wrapper/helper scripts etc for rsnapshot
* http://rsnapshot.org/
* https://github.com/rsnapshot/rsnapshot

Note that the shell scripts here use /opt/bin/bash , for Synology Linux with ipkg or similar.
If you're using this on a standard linux you'll have to change shebang or add a /opt/bin/bash -> /bin/bash symlink.
Unfortunately adding a /bin/bash -> /opt/bin/bash on Synology triggers the security alerts, so that is no-go.

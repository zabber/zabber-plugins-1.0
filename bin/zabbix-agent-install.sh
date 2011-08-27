#!/bin/bash

if [ "$1" = "-h" ]; then
	cat <<EOF
Zabbix agent binary installation script.

(C) SkyCover. http://www.skycover.ru/

Usage:
$0
to automatic download and detect zabbix binary package.
Or
$0 zabbix_agent_binary_package.tar.gz
to specify zabbix binary package as argument.

Zabbix agent binary package should be downloaded from
http://www.zabbix.com/downloads/ for your Linux kernel version
and placed to the local directory.

The file should be specified without path.
EOF
exit 1
fi

bin_prefix=/usr/local
confdir=/etc/zabbix
logdir=/var/log/zabbix-agent
# for compatibility
homedir=/var/run/zabbix-server
initscript=/etc/init.d/zabbix-agent
instlog=agent_install.log
user=zabbix
group=zabbix

test -f "$instlog" && mv "$instlog" "$instlog.old"

{
cat <<EOF

Installing Zabbix agent binary

The installation log will be in "$instlog"

/bin and /sbin will be under $bin_prefix
config will be in $confdir
logs will be in $logdir
home will be in $homedir
agent's user.group will be $user.$group
EOF

Z=`which zabbix_agentd`
if [ -f /usr/sbin/zabbix_agentd ]; then
	cat <<EOF

STOP!!!!

Zabbix agent daemon found in /usr/sbin
This probably means that zabbix agent OS package is installed.
You should remove the package to avoid version conflicts.
EOF
	exit 1
fi

set -e
echo Check for user and group
getent group $group || groupadd $group
getent passwd $user || useradd $user -s/bin/false -d $homedir -U $group

if [ -n "$1" ]; then
	binfile="$1"
else
url=`uname -a|awk '
BEGIN{
u["2.4+i386"]="http://www.zabbix.com/downloads/1.8.5/zabbix_agents_1.8.5.linux2_4.i386.tar.gz"
u["2.6+i386"]="http://www.zabbix.com/downloads/1.8.5/zabbix_agents_1.8.5.linux2_6.i386.tar.gz"
u["2.6+x86_64"]="http://www.zabbix.com/downloads/1.8.5/zabbix_agents_1.8.5.linux2_6.amd64.tar.gz"
u["2.6.23+i386"]="http://www.zabbix.com/downloads/1.8.5/zabbix_agents_1.8.5.linux2_6_23.i386.tar.gz"
u["2.6.23+x86_64"]="http://www.zabbix.com/downloads/1.8.5/zabbix_agents_1.8.5.linux2_6_23.amd64.tar.gz"
}
//{
if($3 ~ /^2.4/)s="2.4"
else if($3 ~ /^2.6.2[3-9]/)s="2.6.23"
else if($3 ~ /^2.6.[3-9]/)s="2.6.23"
else if($3 ~ /^2.6/)s="2.6"
print u[s"+"$(NF-1)]
}
'`
	if [ -z "$url" ]; then
		echo There is no binary file for this architecture:
		uname -a
		echo Please leave message on http://cp.skycover.ru/feedback/
	else
		echo Downloading "$url"
		binfile=`echo $url|awk -F/ '{print $NF}'`
		echo Binary file will be $binfile
		test -f "$binfile" && mv "$binfile" "$binfile.old"
		wget "$url"
	fi
fi

if [ ! -f "$binfile" ]; then
	echo File "$1" not found
	exit 1
fi

echo Creating directories
mkdir -p $bin_prefix/bin $bin_prefix/sbin $confdir $logdir
chown $user.$group $logdir
chmod 700 $logdir
chown root.root $confdir
chmod 755 $confdir

echo Unpacking
wd=`pwd`
(cd $bin_prefix; tar zxvf $wd/$binfile)

echo Creating initscript
cat <<EOF >$initscript
#! /bin/sh
### BEGIN INIT INFO
# Provides:          zabbix-agent
# Required-Start:    \$remote_fs \$network 
# Required-Stop:     \$remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start zabbix-agent daemon
### END INIT INFO

set -e

NAME=zabbix_agentd
DAEMON=/usr/local/sbin/\$NAME
DESC="Zabbix agent"

test -x \$DAEMON || exit 0

DIR=/var/run/zabbix-agent
PID=\$DIR/\$NAME.pid
RETRY=15

if test ! -d "\$DIR"; then
  mkdir "\$DIR"
  chown -R zabbix:zabbix "\$DIR"
fi

export PATH="\${PATH:+\$PATH:}/usr/local/sbin:/usr/sbin:/sbin"

case "\$1" in
  start)
    echo "Starting \$DESC" "\$NAME"
    \$DAEMON >/dev/null 2>&1
    case "\$?" in
        0) echo OK ;;
        *) echo Failed; exit 1 ;;
    esac
	;;
  stop)
    #XXX Ugly? Yes.
    echo "Stopping \$DESC" "\$NAME"
    killall \$DAEMON
    ps axo cmd|grep -q ^\$DAEMON && (sleep 5; ps axo cmd|grep -q ^\$DAEMON && killall -9 \$DAEMON)
    case "\$?" in
        0) echo Ok ;;
        *) echo Failed; exit 1 ;;
    esac
	;;
  status)
   ps axo cmd|grep -q ^\$DAEMON
   if [ \$? -eq 0 ]; then
       echo "\$DESC is running"
       exit 0
   else
       echo "\$DESC is NOT running"
       exit 1
   fi
   ;;
  restart|force-reload)
	\$0 stop
	\$0 start
	;;
  *)
    echo "Usage: /etc/init.d/\$NAME {start|stop|restart|force-reload}" >&2
	exit 1
	;;
esac

exit 0
EOF
chmod 755 $initscript
echo Done
} 2>&1 |tee "$instlog"

#!/bin/bash

if [ -z "$1" -o ! -f "$1" ]; then
	cat <<EOF
Zabbix agent binary installation script.

(C) SkyCover. http://www.skycover.ru/

Usage: $0 zabbix_agent_binary_package.tar.gz

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
user=zabbix
group=zabbix

cat <<EOF

Installing Zabbix agent binary

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

echo Creating directories
mkdir -p $bin_prefix/bin $bin_prefix/sbin $confdir $logdir
chown $user.$group $logdir
chmod 700 $logdir
chown root.root $confdir
chmod 755 $confdir

echo Unpacking
wd=`pwd`
(cd $bin_prefix; tar zxvf $wd/$1)
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

#!/bin/bash
prefix=/usr/local/zabber-plugins
agentconf=/etc/zabbix/zabbix_agentd.conf

set -e
wd=`pwd`
cd ..
mkdir -p $prefix

cp -a $wd/* $prefix
cd $prefix
if [ "$1" != "noagent" ]; then
	if [ -f /usr/sbin/zabbix_agentd ]; then
		echo ============================================================
		echo Zabbix Agent already installed. Skipping agent installation.
		echo ============================================================
	else
		bin/zabbix-agent-install.sh
	fi
fi

bin/update-zabber-plugins

echo Done.

cat <<EOF

You should place right config into $agentconf 

You can get it from http://www.zabber.ru service.
EOF

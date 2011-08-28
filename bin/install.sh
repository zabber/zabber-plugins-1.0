#!/bin/bash
prefix=/usr/local/zabber-plugins
agentconf=/etc/zabbix/zabbix_agentd.conf

set -e
wd=`pwd`
cd ..
mkdir -p $prefix

cp -a $wd/* $prefix
cd $prefix
test "$1" != "noagent" && bin/zabbix-agent-install.sh
bin/update-zabber-plugins

echo Done.

cat <<EOF

You should place right config into $agentconf 

You can get it from http://www.skycover.ru service.
EOF

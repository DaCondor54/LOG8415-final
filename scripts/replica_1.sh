#!/bin/bash

sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install mysql-server sysbench -y


CONFIG_FILE="/etc/mysql/mysql.conf.d/mysqld.cnf"
SOURCE_HOST=$(dig +short source.internal)
REPLICA_PASS="Replic@1"


sudo sed -i "s/^# server-id.*$/server-id = 2/" "$CONFIG_FILE"
sudo sed -i "s/^# log_bin/log_bin/" "$CONFIG_FILE"
sudo sed -i "s/^# binlog_do_db.*$/binlog_do_db = sakila/" "$CONFIG_FILE"
sudo sed -i "78i\relay-log = /var/log/mysql/mysql-relay-bin.log" "$CONFIG_FILE"

sudo systemctl restart mysql

MASTER_STATUS=$(mysql -h source.internal -u replica_1 -p$REPLICA_PASS -e "SHOW MASTER STATUS;" -s)

SOURCE_LOG_FILE=$(echo "$MASTER_STATUS" | tail -n 1 | awk '{print $1}')
SOURCE_LOG_POS=$(echo "$MASTER_STATUS" | tail -n 1 | awk '{print $2}')

sudo mysql <<EOF

CHANGE REPLICATION SOURCE TO
SOURCE_HOST='$SOURCE_HOST',
SOURCE_USER='replica_1',
SOURCE_PASSWORD='$REPLICA_PASS',
SOURCE_LOG_FILE='$SOURCE_LOG_FILE',
SOURCE_LOG_POS=$SOURCE_LOG_POS;

START REPLICA;
EOF
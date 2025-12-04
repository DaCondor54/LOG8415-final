#!/bin/bash

sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install mysql-server sysbench -y


export SOURCE_PUBLIC_IP=$(hostname -I)
export CONFIG_FILE="/etc/mysql/mysql.conf.d/mysqld.cnf"


sudo sed -i "s/^# server-id.*$/server-id = 2/" "$CONFIG_FILE"
sudo sed -i "s/^# log_bin/log_bin/" "$CONFIG_FILE"
sudo sed -i "s/^# binlog_do_db.*$/binlog_do_db = sakila/" "$CONFIG_FILE"
sudo sed -i "78i\relay-log = /var/log/mysql/mysql-relay-bin.log" "$CONFIG_FILE"

sudo systemctl restart mysql

mysql -h source.internal -u replica_1 -pReplic@1 <<EOF

EOF


sudo mysql <<EOF

CHANGE REPLICATION SOURCE TO
SOURCE_HOST='10.0.4.173',
SOURCE_USER='replica_1',
SOURCE_PASSWORD='Replic@1',
SOURCE_LOG_FILE='mysql-bin.000001',
SOURCE_LOG_POS=5073;

START REPLICA;
EOF
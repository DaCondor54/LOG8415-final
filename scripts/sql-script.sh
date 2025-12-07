#!/bin/bash

sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install mysql-server sysbench -y

wget https://downloads.mysql.com/docs/sakila-db.tar.gz
tar -xvzf sakila-db.tar.gz -C /tmp/

sudo mysql <<EOF

SOURCE /tmp/sakila-db/sakila-schema.sql;
SOURCE /tmp/sakila-db/sakila-data.sql;

CREATE USER 'sysbench-user'@'localhost' IDENTIFIED BY 'P@ssword123';
GRANT ALL ON sakila.* TO 'sysbench-user'@'localhost';

EOF

sudo sysbench /usr/share/sysbench/oltp_read_only.lua --mysql-db=sakila --mysql-user="sysbench-user" --mysql-password="P@ssword123" prepare
sudo sysbench /usr/share/sysbench/oltp_read_only.lua --mysql-db=sakila --mysql-user="sysbench-user" --mysql-password="P@ssword123" run

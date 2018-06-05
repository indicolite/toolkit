#!/bin/sh

DATE=`date +%s`

mysqldump --single-transaction --flush-logs --master-data=2 --all-databases > /home/db/backup_${DATE}.sql;

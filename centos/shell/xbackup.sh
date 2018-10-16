#!/bin/bash
###############################################################
## Running by root, Please Install percona-xtrabackup and ceph in advance, and rbd mapped.
## Function : MySQL/MariaDB xtrabackup (Full and Incremental)
## For Ubuntu Server (14.04)
###############################################################

BASEPATH="/home"
SCRIPT="/usr/local/bin/xbackup.sh"
BACKUPPATH="$BASEPATH/db-backup"
BACKUPPATH_FULL="$BASEPATH/db-backup/FULL"
BACKUPPATH_INCR="$BASEPATH/db-backup/INCR"
BACKUPPATH_TARS="$BASEPATH/db-backup/TARS"
BACKUPPATH_TEMP="$BASEPATH/db-backup/TEMP"
BACKUPPATH_TEMP_FULL="$BACKUPPATH_TEMP/FULL"
BACKUPPATH_TEMP_INCR="$BACKUPPATH_TEMP/INCR"
BACKUPPATH_CEPH="/data/rbd_backup_db/"
#BACKUP_SOURCE="jydatapool1"
LOG_PATH="/var/log/xbackup.log"
DBUSER="root"
DBPASSWD="Abc12345"
DATE1=$(/bin/date +"%Y%m%d_%H")
DATE2=$(/bin/date +"%Y%m%d_%H%M")
BASECMDS="--user=$DBUSER --password=$DBPASSWD --parallel=4 --no-timestamp --ftwrl-wait-threshold=40 --ftwrl-wait-query-type=all --ftwrl-wait-timeout=180 --kill-long-queries-timeout=20 --kill-long-query-type=all"

## README ##
README()
{
	echo ""
	echo " ------------------------- Read Me --------------------------- "
	echo "    Usage: $0 [ -full | -incremental | -tar | -h ] "
	echo ""
	echo " ---- -full | -f ---- "
	echo "    Usage: $0 -full "
	echo ""
	echo " ---- -incremental | -i ---- "
	echo "    Usage: $0 -incremental "
	echo ""
	echo " ---- -tar | -t ---- "
	echo "    Usage: $0 -tar "
	echo ""
	echo " ---- -h | -help ---- "
	echo ""
	echo " ---- /etc/cron.d/xbackup ---- "
	echo "0 0 * * * root $SCRIPT -f "
	echo "15 */1 * * * root $SCRIPT -i "
	echo "25 23 * * * root $SCRIPT -t "
	echo "------------------------------------------------------------- "
}

## Check & Create Folders ##
if [ ! -d $BACKUPPATH_FULL ]; then mkdir -p $BACKUPPATH_FULL; fi
if [ ! -d $BACKUPPATH_INCR ]; then mkdir -p $BACKUPPATH_INCR; fi
if [ ! -d $BACKUPPATH_TARS ]; then mkdir -p $BACKUPPATH_TARS; fi
if [ ! -d $BACKUPPATH_CEPH ]; then mkdir -p $BACKUPPATH_CEPH; fi
if [ ! -d $BACKUPPATH_TEMP_FULL ]; then mkdir -p $BACKUPPATH_TEMP_FULL; fi
if [ ! -d $BACKUPPATH_TEMP_INCR ]; then mkdir -p $BACKUPPATH_TEMP_INCR; fi

IF_SUCCESS()
{
	if [ $? -eq 0 ]; then echo " ## [OK] Successed ## ";
	else echo " ## [ERROR] Failed, Try to check log $LOG_PATH ## "; fi
}

LOG_TIME(){
	echo $(/bin/date +"%Y-%m-%d %H:%M:%S") >> $LOG_PATH
}

FULLBACKUP()
{
	LOG_TIME; echo " ## [INFO] Full Backup running, Please wait... ## " >> $LOG_PATH
        touch $BACKUPPATH_FULL/lock
	LOG_TIME; innobackupex $BASECMDS $BACKUPPATH_FULL/$DATE1 >> $LOG_PATH 2>&1; IF_SUCCESS
        rm -f $BACKUPPATH_FULL/lock
}

INCREMENTAL()
{
	if [ -f "$BACKUPPATH_FULL/lock" ]; then
		echo " ## [WARNING] Full backup is still running, can not execute incremental backup ## " > $LOG_PATH;
		exit 0;
	fi

	LASTPATH_INCR=`ls -ct $BACKUPPATH_INCR | head -n 1`
	INCRCMDS2="--incremental $BACKUPPATH_INCR/$DATE2 --incremental-basedir=$BACKUPPATH_INCR/$LASTPATH_INCR"

	CHECKFULL=`ls $BACKUPPATH_FULL`
	if [ "$CHECKFULL" == "" ]; then
		LOG_TIME; echo " ## [WARNING] Full backup is NOT exsit ## " >> $LOG_PATH;
		FULLBACKUP;
	fi

	CHECKFIRST=`ls $BACKUPPATH_INCR`
	if [ "$CHECKFIRST" == "" ]; then
		LASTPATH_FULL=`ls -ct $BACKUPPATH_FULL | head -n 1`
		INCRCMDS1="--incremental $BACKUPPATH_INCR/$DATE2 --incremental-basedir=$BACKUPPATH_FULL/$LASTPATH_FULL"
		LOG_TIME; echo " ## [INFO] Incremental 'First' Backup running, Please wait... ## " >> $LOG_PATH 2>&1
		LOG_TIME; innobackupex $BASECMDS $INCRCMDS1 >> $LOG_PATH 2>&1
		IF_SUCCESS
	else
		LOG_TIME; echo " ## [INFO] Incremental Backup running, Please wait... ## " >> $LOG_PATH
		LOG_TIME; innobackupex $BASECMDS $INCRCMDS2 >> $LOG_PATH 2>&1
		IF_SUCCESS
	fi
}

TARFILES()
{
	LOG_TIME; echo " ## [INFO] Creating TAR(GZIP) Files, Please wait... ## " >> $LOG_PATH
	mv $BACKUPPATH_FULL/* $BACKUPPATH_TEMP_FULL
	LOG_TIME; tar zcvf $BACKUPPATH_TARS/$DATE1"_FULL".tgz $BACKUPPATH_TEMP_FULL > $LOG_PATH 2>&1; IF_SUCCESS
	mv $BACKUPPATH_INCR/* $BACKUPPATH_TEMP_INCR
	LOG_TIME; tar zcvf $BACKUPPATH_TARS/$DATE1"_INCR".tgz $BACKUPPATH_TEMP_INCR > $LOG_PATH 2>&1; IF_SUCCESS
	rm -rf $BACKUPPATH_TEMP_FULL/* $BACKUPPATH_TEMP_INCR/*

	LOG_TIME; echo " ## [INFO] Backup $BACKUPPATH_TARS files ... ## " >> $LOG_PATH
	LOG_TIME; find $BACKUPPATH_TARS -type f -ctime 0 | xargs -i cp {} $BACKUPPATH_CEPH >> $LOG_PATH 2>&1; IF_SUCCESS
	find $BACKUPPATH_CEPH -type f -mtime +7 | xargs rm -rf

	find $BACKUPPATH_TARS -type f -mtime +1 | xargs rm -rf
}

## Mode and README ##
if [ $# -eq 0 ]; then README; fi

while [ $# -gt 0 ]; do
	case  "$1" in
	-full | -f )
		FULLBACKUP
    	;;

	-incremetal | -i )
		INCREMENTAL
	;;

	-tar | -t )
		TARFILES
	;;

	-h | -help )
		README
	;;
	esac
	shift
done

#--throttlea=400
#--use-memory=1G

#! /bin/bash
## Function: For MySQL innodb engine use xtrabackup full and increase recovery.
LOG_PATH="/var/log/xbackup_recovery.log"
DEFAULT_BACKUPPATH=""
DBUSER="root"
DBPASSWD="Abc12345"
#DBCONF="/etc/mysql/my.cnf"
DBCONF="/etc/my.cnf.d/mariadb-server.cnf"
MySQL_DATA_PATH="/var/lib/mysql"
BASECMDS="--defaults-file=$DBCONF --user=$DBUSER --password=$DBPASSWD "
FULL_TAR_PATH=""
INCR_TAR_PATH=""
## Usage ##
USAGE(){
    echo "Usage: ./xbackup_recovery.sh -d default_backuppath -f <backup full tar file path> -i <backup incr tar file path> -h"
    echo "使用定时任务生成的tar包，作为恢复源"
    echo "Example: ./xbackup_recovery.sh -d /home/db-backup/TEMP -f /home/db-backup/TARS/20160317_23_FULL.tgz -i /home/db-backup/TARS/20160317_23_INCR.tgz"
    echo "使用手动打包的最新数据，比如打包/home/db-backup/FULL为XXX_FULL.tgz,作为恢复源"
    echo "Example: ./xbackup_recovery.sh -d /home/db-backup -f XXX_FULL.tgz -i XXX_INCR.tgz"
    exit
}
 
if [ $# -eq 0 ]; then
    USAGE
    exit 0
fi
 
IF_SUCCESS()
{
        if [ $? -eq 0 ]; then echo " ## [OK] Successed ## ";
        else echo " ## [ERROR] Failed, Try to check log $LOG_PATH ## "; fi
}
 
CURRENT_TIME(){
    echo $(/bin/date +"%Y-%m-%d %H:%M:%S")
}
 
RECOVERY(){
    if [ x"$FULL_TAR_PATH" = x"" ] || [ x"$INCR_TAR_PATH" = x"" ] || [ x"$DEFAULT_BACKUPPATH" = x"" ]; then
        echo " ## backup tar file or default_backuppath is none, exit..." >> $LOG_PATH 2>&1
        USAGE
        exit 0
    fi
    BACKUPPATH_INCR="$DEFAULT_BACKUPPATH/INCR"
    BACKUPPATH_FULL="$DEFAULT_BACKUPPATH/FULL"
    echo " ## (backup full file path)=$FULL_TAR_PATH, (backup incr file path)=$INCR_TAR_PATH, (default_backup file path)=$DEFAULT_BACKUPPATH" >> $LOG_PATH 2>&1
 
    echo $(CURRENT_TIME) >> $LOG_PATH; pkill -u mysql >> $LOG_PATH 2>&1; IF_SUCCESS
 
    BACKUPPATH_FULL="/tmp$BACKUPPATH_FULL"
    BACKUPPATH_INCR="/tmp$BACKUPPATH_INCR"
    rm -rf $BACKUPPATH_FULL $BACKUPPATH_INCR
 
    echo $(CURRENT_TIME) >> $LOG_PATH; tar -xzvf $FULL_TAR_PATH -C /tmp/ >> $LOG_PATH 2>&1; tar -xzvf $INCR_TAR_PATH -C /tmp/ >> $LOG_PATH 2>&1
 
    full_dir=`ls -lrt "$BACKUPPATH_FULL" | awk 'END {print $NF}'`
    echo $(CURRENT_TIME) >> $LOG_PATH; innobackupex $BASECMDS --apply-log --redo-only $BACKUPPATH_FULL/$full_dir >> $LOG_PATH 2>&1; IF_SUCCESS
 
    incr_list=(`ls -lrt "$BACKUPPATH_INCR" | awk 'NR>1{print $NF}'`)
    incr_num=${#incr_list[@]}
    for ((i=0; i<$incr_num; i++)); do
        if [ $i -eq `expr $incr_num - 1` ]; then
            echo $(CURRENT_TIME) >> $LOG_PATH; innobackupex $BASECMDS --apply-log $BACKUPPATH_FULL/$full_dir --incremental-dir=$BACKUPPATH_INCR/${incr_list[$i]} >> $LOG_PATH 2>&1; IF_SUCCESS
        else
            echo $(CURRENT_TIME) >> $LOG_PATH; innobackupex $BASECMDS --apply-log --redo-only $BACKUPPATH_FULL/$full_dir --incremental-dir=$BACKUPPATH_INCR/${incr_list[$i]} >> $LOG_PATH 2>&1; IF_SUCCESS
        fi
    done
 
    mkdir -p /tmp/mysql/data/$(/bin/date +"%Y%m%d_%H%M")
    mv $MySQL_DATA_PATH/* /tmp/mysql/data/$(/bin/date +"%Y%m%d_%H%M")
    echo "innobackupex $BASECMDS --copy-back $BACKUPPATH_FULL/$full_dir"
 
    echo $(CURRENT_TIME) >> $LOG_PATH; innobackupex $BASECMDS --copy-back $BACKUPPATH_FULL/$full_dir >> $LOG_PATH 2>&1; IF_SUCCESS
 
    chown -R mysql:mysql $MySQL_DATA_PATH/*; IF_SUCCESS
 
    echo $(CURRENT_TIME) >> $LOG_PATH; systemctl start mariadb >> $LOG_PATH 2>&1; IF_SUCCESS
}
 
while getopts ":d:f:i:h" arg
do
    case $arg in
        d)
            DEFAULT_BACKUPPATH=$OPTARG
            echo "$OPTARG"
            ;;
        f)
            FULL_TAR_PATH=$OPTARG
            echo "$OPTARG"
            ;;
        i)
            INCR_TAR_PATH=$OPTARG
            echo "$OPTARG"
            ;;
        h)
            USAGE
            ;;
        \?)
            echo "Unkonw argument, use -h for help"
    exit 1
    ;;
    esac
done
RECOVERY

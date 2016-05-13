#!/bin/bash
## Filename:daily_hotback_up.sh
## 1 */3 * * *	/bin/bash /root/shell/daily_hotback_up.sh dbname1 dbname2 >/dev/null 2>&1
## GRANT SELECT, RELOAD, SUPER, REPLICATION CLIENT ON *.* TO 'mysql_backup'@'localhost' IDENTIFIED BY 'mysql_backup';
## FLUSH PRIVILEGES;
## if normal usr run this script, you can set sudo visudo Defaults:deploy    !requiretty
## fix DB variable 2016/3/31, How to automatically identify the DB variable parameters?


source /etc/profile
echo $PATH|grep -wq '/usr/local/sbin' || PATH=${PATH}:/usr/local/

DAY=$(date "+%Y%m%d")
day=$(date +"%F")
TIME=$(date "+%H%M")
MY_IP=$(/sbin/ip a|grep '\<inet\>'|grep -Ev ":|127.0.0.1"|grep -E "172\."|awk '{print $2|"xargs dirname"}'|head -1)

#以IP标识，统一路径存储
RSYNC_PATH="/data/mysql_backup/full_back/$MY_IP"
INNOBA="/data/mysql_backup/innobackupex_backup/${MY_IP}/"
INNOBACKUP_PATH="/data/mysql_backup/innobackupex_backup/${MY_IP}/${DAY}/"
LIST_PATH="/data/mysql_backup/innobackupex_backup/list/"
SQL_PATH="/data/mysql_backup/full_back/$MY_IP/"
LOG_PATH="/tmp/log/mysql_full_back_up/"
LOG=${LOG_PATH}"daily_hotback_up"$(date +%F).log
SQL="${MY_IP}_all_$(date +"%F").sql"

#使用mysql_backup用户进行本地dump操作
DB="$1 $2 $3 $4"
DB_USER="mysql_backup"
DB_PW="mysql_backup"
BACK_UP_SERVER="172.31.100.254"
SLEEP_TIME=$(expr $(/usr/bin/hexdump -n4 -e\"%u\" /dev/urandom) % 3600)


mkdir -p ${SQL_PATH}inc $INNOBACKUP_PATH $LIST_PATH $LOG_PATH


function REPORT
{   
        echo -e "[`date +%F-%H-%M-%S`] $1" | tee -a $LOG
        [ $# -eq 2 ] && exit 1 || return 0
}

function REPORTINFO
{
        REPORT "[INFO] $1"
}

function REPORTWARN
{
        REPORT "[WARNING] $1"
}


function report
{
# 日志记录
# $1为记录并输出的内容
	echo "`date +"%F %T":` $1" >> $LOG
}
report "[INFO] sleep $SLEEP_TIME seconds and begin to mysqldump $SQL"


#判断从库硬盘空间状况
function disk_space
{
	#空闲少于20G，报错退出
	if [[ `df | grep data | awk '{print $4}'` -lt 20000000 ]] ; then
		REPORTWARN "$SQL slave do not have enough space to mysqldump, exit"
	else
		:
	fi
}


function dump_all_zip
{
#本地全dump&zip
        local st=`date "+%s"`
	report "[INFO] now begin to full mysqldump."
	cd $INNOBA && ls |grep -v "${DAY}" |xargs rm -rf || REPORTWARN "cd $INNOBA err"
	local msg="${INNOBACKUP_PATH}all"
	sudo `which innobackupex` --user=$DB_USER --password=$DB_PW --no-timestamp --databases="$DB" ${INNOBACKUP_PATH}all

	[ $? -eq 0 ] || REPORTWARN "dump_all_zip:backup db err"
	sudo chown -R deploy:deploy ${INNOBACKUP_PATH}
	cd ${INNOBACKUP_PATH}all && \
	tar zhcf ${SQL_PATH}${SQL}.tgz *
	[ $? -eq 0 ] && echo $msg >> ${LIST_PATH}${DAY}.list || REPORTWARN "dump_all_zip:tar db package err"
        report "[INFO] mysqldump finish"

        local et=`date "+%s"`
        local time_min=`expr $[${et} -${st}] / 60 `
        report "[TIME_DUMP_ZIP] USE TIME_DUMP_ZIP ${time_min} minutes"
}


function dump_incremental_zip
{
#本地增量dump&zip
        local  op=`date "+%s"`
	report "[INFO] now begin to mysqldump"
	if [[ $(tail -1 ${LIST_PATH}${DAY}.list) = ${INNOBACKUP_PATH}all ]]
	then
		local num=1
	elif $(tail -1 ${LIST_PATH}${DAY}.list|grep -q "inc-[0-9][0-9]*$")
	then
		local num=$(expr $(tail -1 ${LIST_PATH}${DAY}.list|grep -o "[0-9][0-9]*$") + 1 )
	else
		REPORTWARN "all back up err:dump_incremental_zip"
	fi
	local basedir=$(tail -1 ${LIST_PATH}${DAY}.list)
	[ -d $basedir ] || REPORTWARN "dump_incremental_zip:incremental basedir err"
	cd $INNOBA || REPORTWARN "cd $INNOBA err"
	sudo `which innobackupex` --user=$DB_USER  --password=$DB_PW --no-timestamp --database="$DB" --incremental --incremental-basedir=$basedir ${INNOBACKUP_PATH}inc-$num
	[ $? -eq 0 ] || REPORTWARN "dump_incremental_zip:backup db-$num err"
	sudo chown -R deploy:deploy ${INNOBACKUP_PATH}
	cd ${INNOBACKUP_PATH}inc-$num && \
	tar zhcf ${SQL_PATH}inc/${MY_IP}_inc-${num}_$(date +"%F").sql.tgz *
	[ $? -eq 0 ] && echo "${INNOBACKUP_PATH}inc-$num" >> ${LIST_PATH}${DAY}.list || REPORTWARN "dump_incremental_zip:tar db package-$num err"
	local md5=$(md5sum ${SQL_PATH}inc/${MY_IP}_inc-${num}_$(date +"%F").sql.tgz|awk '{print $1}')
	local INC_MD5=${SQL_PATH}inc/${MY_IP}_inc-${num}_$(date +"%F")_${md5}.sql.tgz
	mv ${SQL_PATH}inc/${MY_IP}_inc-${num}_$(date +"%F").sql.tgz $INC_MD5
	report "[INFO] mysqldump finish"
        local ed=`date "+%s"`
        local time_min=`expr $[${ed} -${op}] / 60 `
        report "[TIME_DUMP_ZIP] USE TIME_DUMP_ZIP ${time_min} minutes"
}

#判断文件mysqldump是否正常 大于1G
function dump_check
{
	if [[ `du -b ${SQL_PATH}${SQL}.tgz |awk '{print $1}'` -lt 1048576 ]] 
	then
	     cd ${SQL_PATH} && rm -rf *
	     REPORTINFO "$SQL dump is error. check it"
		 exit 1
	fi
}

#传输
function sync_clear
{

	if ! [ "$1" ]
	then
		SQL_MD5=`md5sum ${SQL_PATH}${SQL}.tgz |awk '{print $1}'`
		SQL_NAME_WITH_MD5="${MY_IP}_all_${day}_${SQL_MD5}.sql.tgz"
		cd $SQL_PATH && mv $SQL.tgz $SQL_NAME_WITH_MD5
		SQL=$SQL_NAME_WITH_MD5
	fi
	local count="1"
	#1传输
	while :
	do
		local op=`date "+%s"`
		report "[INFO] now begin to rsync the ${SQL} to $BACK_UP_SERVER:backup"
		rsync -av $RSYNC_PATH $BACK_UP_SERVER:/backup/mysql_backup/
		if [ $? -eq 0 ]
		then
			report "[INFO] rsync $SQL successfully"
			break
		else
			report "[WARN] rsync $SQL to $BACK_UP_SERVER failed"
			if [ $count -eq 5 ] ; then
				REPORTWARN "rsync error 1, exit"
			else
				((count++))
				sleep 3
			fi
		fi
	done
	report "[INFO] rsync finish"
	local ed=`date "+%s"`
	local time_min=`expr $[${ed} -${op}]`
	report "[TIME_RSYNC] USE TIME_RSYNC ${time_min} seconds "
	if [ "$1" ]
	then
		rm -rf ${SQL_PATH}*
	fi
}


function CHECK_LIST
{
        find ${LIST_PATH} -type f -ctime +2 -exec sudo chattr -a {} \; -exec rm -f {} \;
        if [ -f ${LIST_PATH}${DAY}.list ]
        then
                if [ -s ${LIST_PATH}${DAY}.list ]
                then
                        if $(lsattr ${LIST_PATH}${DAY}.list|grep -q '\-----a-------')
                        then
                                [ $(cat ${LIST_PATH}${DAY}.list|wc -l) -eq 1 ] && REPORTWARN "allbackup dir is err"
                                if [[ $(head -1 ${LIST_PATH}${DAY}.list) = ${DAY} ]]
                                then
                                        if ! [ -f $(sed -n '2p' ${LIST_PATH}${DAY}.list) ]
                                        then
                                                if ! [ -d $(sed -n '2p' ${LIST_PATH}${DAY}.list) ]
                                                then
                                                    REPORTWARN "allbackup dir is err"
                                                fi
                                        fi
                                else
                                        REPORTWARN "${LIST_PATH}${DAY}.list date is err"
                                fi
                        else
                                REPORTWARN "${LIST_PATH}${DAY}.list Permission is err"
                        fi
                else
                        REPORTWARN "${LIST_PATH}${DAY}.list is null"
                fi
        else
                touch ${LIST_PATH}${DAY}.list && \
                sudo chattr +a ${LIST_PATH}${DAY}.list && \
                echo ${DAY} >> ${LIST_PATH}${DAY}.list
                [ $? -eq 0 ] || REPORTWARN "touch ${LIST_PATH}${DAY}.list err"
        fi
}



function DUMP_XTR
{
        case $(sed -n '2p' ${LIST_PATH}${DAY}.list) in
                ${INNOBACKUP_PATH}all)
                        if [ -d ${INNOBACKUP_PATH}all ]
                        then
                                dump_incremental_zip
                                ##sleep $SLEEP_TIME
                                sync_clear 1
                        else
                                REPORTWARN "allbackup dir is err"
                        fi
                ;;
                "")
                        ##sleep $(expr $(/usr/bin/hexdump -n4 -e\"%u\" /dev/urandom) % 900)
                        dump_all_zip
                        #dump_check
                        ##sleep $SLEEP_TIME
                        sync_clear
                ;;
                *)
                        REPORTWARN "first backup err"
                ;;
        esac
}


if `which innobackupex` -version > /dev/null 2>&1
then
        CHECK_LIST
        op=`date "+%s"`
        ##disk_space
        DUMP_XTR
        ed=`date "+%s"`
        time_min=`expr $[${ed} -${op}] / 60`
        report "[INFO] back up done"
        report "[TIME_ALL] USE TIME_ALL ${time_min} minutes"
else
        REPORTWARN "innobackupex command not found or version err"
fi

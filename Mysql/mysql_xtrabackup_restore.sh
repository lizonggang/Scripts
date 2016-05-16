#!/bin/bash
###################################ȫ�ֱ���-��������Ҫ�ı���###########################
#����ʱ�����#
TIME=`date +%F_%T`
DAY=`date +%F`
#���屾��IP,�˴�����ƽ̨������IP,�ñ���������Ҫ�ٶ�
LOCAL_PRI_IP="$1"
#���屾�ű�ȥ��.sh�������####
SCRIPT_NAME=`basename ${0%.*}`
#���ݱ��ű��������Զ�����־������ű���run.sh,��־����run_${TIME}.log
#Ϊ�˷�ֹ��Ŀ¼�ṹ��ʹ����basenameȥ��Ŀ¼�ṹ  ${0%.*}��˼��ȥ���ñ���.֮�����������
LOG_NAME="${SCRIPT_NAME}_${TIME}.log" 
#���������־��·��Ϊ/�����û���Ŀ¼/shell/log/,��Ԥ����#####
LOG_PATH="${HOME}/shell/log/${SCRIPT_NAME}/"
mkdir -p ${LOG_PATH} || exit 1
#�������Ŀ¼
DATA_PATH="/data/" 
#����/data/repos/Ŀ¼,��Ԥ����##
REPOS_PATH="/data/repos/"
#����pid���
PID_DIR="/var/run/qxscript/"
SCRIPT_PID="${SCRIPT_NAME}.pid"
MY_CNF="/etc/my.cnf"
mkdir -p ${REPOS_PATH} ${PID_DIR}|| exit 1

#####################################�·���װģ����Ҫ���±���#########################
#�����ȡ�ķ�������Ϣlist�ļ���

#���尲װ�����ڴ洢��IP
BACKUP_IP="10.30.34.209"
#���尲װ�����ڴ洢��Ŀ¼##��Ҫ�Լ�����
INSTALL_PACKAGE_PATH="/data/server_install_package/xtrabackup_install_package/"
#���尲װ�����ļ���##��Ҫ�Լ�����
INSTALL_PACKAGE="*_SERVER_INSTALL.tgz"
#���尲װ����MD5##��Ҫ�Լ�����
INSTALL_PACKAGE_MD5="xtrabackup_install_package/xtrabackup_md5"
#������ȡ��Ϸ��Դ�ķ�����IP###��Ҫ�Լ�����
GAME_RESOURCE_IP="10.22.222.31"
#�����������key���ڵ�Ŀ¼
LICENSE_PATH="/data/license/"
#����ftp�ϴ��license��Ŀ¼
FTP_LICENSE_PATH="/license"
#��Ϸ���ݿ�����####��Ҫ�Լ�����
GAMEDB_NAME="mmo"
GAMEDB_LOG_NAME="mmo_log"

MYSQL_USE="mysql_backup"
MYSQL_PWD="mysql_backup"
LPWD="$(pwd)/"
LIST="${LPWD}list"
LIST_INFO="${LPWD}list_info"
FAIL_LIST="${LPWD}fail_list"
MD5_FILE="${LPWD}xtrabackup_md5"
LOG_TMP="${LPWD}log.tmp"
OMSIP="10.30.32.182"
REIP="10.22.222.243"
CHAR="latin1"
FTP_USE="yunwei"
FTP_PWD="game@yunwei"
FTP_IP=$BACKUP_IP
SCP_IP_TJ="10.22.222.51"
SCP_IP_DLS="10.51.34.46"
SCP_IP_HK="10.52.33.18"
MY_IP=$(/sbin/ip a|grep inet|grep -Ev ":|127.0.0.1"|grep -E "10\."|awk '{print $2|"xargs dirname"}')
INC=0

function REPORT
{   
    #������ʾ ���磺echo -e "\033[33m \033[1m ��ȷ���Ƿ�Ҫֹͣ��ǰ��squid����,���� [Y/N] \033[0m"
    #��ע��echo -e  "\" ��ʹ��
	#\a ������������\b ɾ��ǰһ���ַ���\c ��󲻼��ϻ��з��ţ�\f ���е�����Ծ�ͣ����ԭ����λ�ã�\n �����ҹ���������ף�\r ����������ף��������У�\t ����tab�� \v ��\f��ͬ�� \\ ����\�ַ���\nnn ����nnn���˽��ƣ��������ASCII�ַ���
	echo -e "[`date +%F-%H-%M-%S`] $1" | tee -a ${LOG_PATH}${LOG_NAME}
	[ $# -eq 2 ] && exit 1 || return 0
}

#Extension of REPORT����ʾ��Ϣ
function REPORTINFO
{
	REPORT "[INFO] $1"
}


#Extension of REPORT������ & �˳�
function REPORTWARN
{
	REPORT "[WARNING] $1" 1
}

function PROC_CHECK
{
	ps aux|grep -qw "htt[p]d" && REPORTWARN "httpd is running, plz stop it"
	ps aux|grep -qw "squi[d]" && REPORTWARN "squid is running, plz stop it"
	ps aux|grep -qw "mysq[l]d.*datadir=$DATA_DIR" && REPORTWARN "mysqld is running, plz stop it"
	ps aux|grep -qw "jav[a]" && REPORTWARN "java is running, plz stop it"
}

function RESTORE_MYSQL
{
	ZXF_PACKAGE
	APPLY_LOG
	COPY_BACK
}

function ZXF_PACKAGE
{
	REPORTINFO "now extract all package, plz wait ..."
	tar zxf ${REPOS_PATH}${FILE_NAME} -C ${REPOS_PATH}backup/all || REPORTWARN "extract all package err"
	local db_names=$(find ${REPOS_PATH}backup/all -type d |grep -v 'all$' |sed 's#.*all/\(.*\)#\1#g'|xargs )
	local innodb_data_file_path_all=$(grep innodb_data_file_path ${REPOS_PATH}backup/all/backup-my.cnf|awk -F= '{print $NF}')
	while :
	do
	sed -n '/\[mysqld\]/,/\[/p' $MY_CNF |grep -qw "$innodb_data_file_path_all" && break || {
	sed -n '/\[mysqld\]/,/\[/p' $MY_CNF |grep -w "innodb_data_file_path"|sed 's/ //g'
	grep innodb_data_file_path ${REPOS_PATH}backup/all/backup-my.cnf
	REPORTINFO "innodb configuration is inconsistent, plz edit"
	echo "�޸ĺ�enterȷ��";read a
	}
	done
	mkdir -p /data/data_mysql_bak/
	cd $DATA_DIR && mv $db_names /data/data_mysql_bak/${db_names}_$(date +%F_%T)
	REPORTINFO "extract all package done"
	if [ $INC -ne 0 ]
	then
		for ((i=1;i<=$INC;i++))
		do
		REPORTINFO "now extract inc-$i package, plz wait ..."
		tar zxf ${REPOS_PATH}${FILE_IP}_inc-${i}_${FILE_DATE}*.sql.tgz -C  ${REPOS_PATH}backup/inc-$i || REPORTWARN "extract inc-$i package err"
		REPORTINFO "extract inc-$i package done"
		done
	fi
}
function APPLY_LOG
{
	REPORTINFO "now apply log for all package, plz wait ..."
	$(which innobackupex) --user=mysql_backup --password=mysql_backup --defaults-file=$MY_CNF --apply-log ${REPOS_PATH}backup/all  || REPORTWARN "apply log for all package err"
	REPORTINFO "apply log for all package done"
	if [ $INC -ne 0 ]
	then
		for ((i=1;i<=$INC;i++))
		do
		REPORTINFO "now apply log for inc-$i package, plz wait ..."
		$(which innobackupex) --user=mysql_backup --password=mysql_backup --defaults-file=$MY_CNF --apply-log --incremental-dir=${REPOS_PATH}backup/inc-$i ${REPOS_PATH}backup/all || REPORTWARN "apply log for inc-$i package err"
		REPORTINFO "apply log for inc-$i package done"
		done
	fi
}

function COPY_BACK
{
	REPORTINFO "now copy back, plz wait ..."
	$(which innobackupex) --user=mysql_backup --password=mysql_backup --defaults-file=$MY_CNF --copy-back ${REPOS_PATH}backup/all || REPORTWARN "file copy back err"
	REPORTINFO "begin to chown"
	chown mysql.mysql -R $DATA_DIR
	REPORTINFO "chown done"
	REPORTINFO "file copy back done"
	REPORTINFO "now you can restart the mysql and check the data "
	rm -rf ${REPOS_PATH}backup
	echo '[ECHO[OK]]'
}

echo $PATH|grep -q "/usr/bin" || export PATH = ${PATH}:/usr/bin
FILE_NAME=$1
[ -s $MY_CNF ] || REPORTWARN "$MY_CNF no found"
DATA_DIR=$(sed -n '/\[mysqld\]/,/\[/p' $MY_CNF|grep -E 'datadir' |awk -F= '{print $NF}'|awk '{print $NF}')
[ "$DATA_DIR" ] || REPORTWARN "datadir & innodb_data_home_dir option err in $MY_CNF"
cat <<eof
############################################################
#Ϊ�˱�֤���ݰ�ȫ�����ڻָ�����ǰ���������ݽ��б��ݡ�
#�˽ű���copy-back����ǰ�����������Ŀ¼���в��� ����ע�⡣
#$DATA_DIR
############################################################
��enterȷ��
eof
read a
REPORTINFO "now mission start, plz wait ..."
if $(which innobackupex) -version >/dev/null 2>&1 
then
	[ $# -eq 1 ] || REPORTWARN "option err"
	echo $FILE_NAME |grep -q '.*_all_.*\.tgz$' || REPORTWARN "the type of backup file err"
	FILE_DATE=$(echo $FILE_NAME |awk -F_ '{print $3}')
	FILE_MD5=$(echo $FILE_NAME |awk -F[_.] '{print $7}')
	FILE_IP=$(echo $FILE_NAME |awk -F_ '{print $1}')
	[ -s ${REPOS_PATH}${FILE_NAME} ] || REPORTWARN "backup tgz err"
	#repos��ֻ�ܷ�all����inc-x��
	[ $(ls ${REPOS_PATH}|grep -vE '.*_all_.*\.tgz|inc-[1-9]' |wc -l) -eq 0 ] || REPORTWARN "some other file in repos path"
	PROC_CHECK
	md5sum ${REPOS_PATH}${FILE_NAME} |grep -qw $FILE_MD5 || REPORTWARN "FILE_NAME md5 err"
	mkdir -p ${REPOS_PATH}backup/all
	rm -rf ${REPOS_PATH}backup/all/*
	ls ${REPOS_PATH} |grep -q "${FILE_IP}_inc-1_${FILE_DATE}.*sql.tgz" && mkdir -p ${REPOS_PATH}backup/inc-1 && INC=1
	[ $? -eq 0 ] && ls ${REPOS_PATH} |grep "${FILE_IP}_inc-2_${FILE_DATE}.*sql.tgz" && mkdir -p ${REPOS_PATH}backup/inc-2 && INC=2
	[ $? -eq 0 ] && ls ${REPOS_PATH} |grep "${FILE_IP}_inc-3_${FILE_DATE}.*sql.tgz" && mkdir -p ${REPOS_PATH}backup/inc-3 && INC=3
	[ $? -eq 0 ] && ls ${REPOS_PATH} |grep "${FILE_IP}_inc-4_${FILE_DATE}.*sql.tgz" && mkdir -p ${REPOS_PATH}backup/inc-4 && INC=4
	[ $? -eq 0 ] && ls ${REPOS_PATH} |grep "${FILE_IP}_inc-5_${FILE_DATE}.*sql.tgz" && mkdir -p ${REPOS_PATH}backup/inc-5 && INC=5
	[ $? -eq 0 ] && ls ${REPOS_PATH} |grep "${FILE_IP}_inc-6_${FILE_DATE}.*sql.tgz" && mkdir -p ${REPOS_PATH}backup/inc-6 && INC=6
	[ $? -eq 0 ] && ls ${REPOS_PATH} |grep "${FILE_IP}_inc-7_${FILE_DATE}.*sql.tgz" && mkdir -p ${REPOS_PATH}backup/inc-7 && INC=7
	[ $? -eq 0 ] && ls ${REPOS_PATH} |grep "${FILE_IP}_inc-8_${FILE_DATE}.*sql.tgz" && mkdir -p ${REPOS_PATH}backup/inc-8 && INC=8
	[ $? -eq 0 ] && ls ${REPOS_PATH} |grep "${FILE_IP}_inc-9_${FILE_DATE}.*sql.tgz" && mkdir -p ${REPOS_PATH}backup/inc-9 && INC=9
	rm -rf ${REPOS_PATH}backup/inc-1/*
	rm -rf ${REPOS_PATH}backup/inc-2/*
	rm -rf ${REPOS_PATH}backup/inc-3/*
	rm -rf ${REPOS_PATH}backup/inc-4/*
	rm -rf ${REPOS_PATH}backup/inc-5/*
	rm -rf ${REPOS_PATH}backup/inc-6/*
	rm -rf ${REPOS_PATH}backup/inc-7/*
	rm -rf ${REPOS_PATH}backup/inc-8/*
	rm -rf ${REPOS_PATH}backup/inc-9/*
	RESTORE_MYSQL
else
	REPORTWARN "innobackupex command not found"
fi











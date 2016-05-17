#!/bin/bash

# mysql备份脚本
source /etc/profile

# 备份目录
BACKUP_ROOT="/data/var/backup/mysql";
# 备份日志目录
BACKUP_LOG="/data/var/log/backup/mysql";
# 备份脚本执行目录
BACKUP_BIN="/data/opt/mysql-backup"

# 默认为全量备份
BACKUP_TYPE="full"
# 全量备份后缀
BACKUP_SUFFIX="full"

# mysql执行目录
MYSQL_BIN="/data/opt/mysql/bin"
# mysql单实例配置文件
MYSQL_CNF="/data/srv/mysql/3306/my.cnf"

# 默认不进行SYNC异地备份
BACKUP_SYNC="no"
# 本地文件自动清除天数
AUTO_CLEAN_DAY=2

# SYNC的模块
SYNC_MODULE="backup"
# SYNC的用户名
SYNC_USER="backup"
# SYNC的密码
export RSYNC_PASSWORD="56kfw8e"

# Print and send message to file
function show_log {
    local datetime=$(date "+%F %T")
    echo -e "$datetime $@" | tee -a $LOG_FILE
}

# 参数说明
function usage
{
cat <<EOF 
mysql-backup use xtrabackup && mysqlhotcopy.

Usage: `basename $0` [-f my.cnf] [-t full|increment] [-b basedir] [-l lsn] [-s no|sync|clean] [-h]

  -h, --help
        This option displays a help screen and exits.
  -f, --defaults-file=[MY.CNF]
        This option specifies what file to read the default MySQL options
        from. The option accepts a string argument. It is also passed
        directly to xtrabackup's --defaults-file option. See the xtrabackup
        documentation for details.
  -t, --type=[full|increment]
        This option tells mysql-backup to create an full or incremental backup . 
        When this option is specified, either --incremental-lsn or
        --incremental-basedir can also be given. If neither option is given,
        option --incremental-basedir is passed to mysql-backup by default.
  -b, --incremental-basedir=DIRECTORY
        This option specifies the directory containing the full backup that
        is the base dataset for the incremental backup. The option accepts a
        string argument. It is used with the --incremental option.
  -l, --incremental-lsn
        This option specifies the log sequence number (LSN) to use for the
        incremental backup. The option accepts a string argument. It is used
        with the --incremental option. It is used instead of specifying
        --incremental-basedir. For databases created by MySQL and Percona
        Server 5.0-series versions, specify the LSN as two 32-bit integers
        in high:low format. For databases created in 5.1 and later, specify
        the LSN as a single 64-bit integer.
  -s, --sync=[no|sync|clean]
        This option set sync send backup file to remote host.If set no will
        not send, if set sync will only send file to remote host but not remove
        local file, if set clean will send file and remove local file.
EOF
exit -1;
}

# 处理传参
function parse_opt
{
	local temp=`getopt -o f:t:b:l:s:h --long defaults-file:,type:,incremental-basedir:,incremental-lsn:,--sync:,help  -- "$@"`
	# Note the quotes around `$TEMP': they are essential!
	eval set -- "$temp"
	
	while true ; do
		case "$1" in
			-f|--defaults-file) MYSQL_CNF=${2} ; shift 2;;
			-t|--type)
				if [ "$2" == "increment" ]; then 
					BACKUP_TYPE="increment"
					BACKUP_SUFFIX="delta"
				fi
				shift 2;;
			-b|--incremental-basedir) 
				BACKUP_BASEDIR=$2; shift 2;;
			-l|--incremental-lsn) 
				BACKUP_BASELSN=$2 ; shift 2 ;;
			-s|--sync)
				BACKUP_SYNC=$2; shift 2;;
			-h|--help) usage; exit 1 ;;
			--) shift ; break ;;
		esac
	done
}


# 备份
function backup
{
	# 先清空目录，防止出错
	rm -rf $BACKUP_DIR/$BACKUP_FILE/*
	show_log "Start mysql backup to $BACKUP_DIR/$BACKUP_FILE ..."

	# 检查是否为增量
	if [ "$BACKUP_TYPE" == "increment" ]; then
		INCREMENT="--incremental-basedir=$BACKUP_LSNDIR"
		if [ "$BACKUP_BASEDIR" != "" ]; then
			INCREMENT="--incremental-basedir=$BACKUP_BASEDIR"
		fi
		if [ "$BACKUP_BASELSN" != "" ]; then
			INCREMENT="--incremental-lsn=$BACKUP_BASELSN"
		fi
	fi

	show_log "Backup innodb ..."
	CMD="$xtrabackup  --defaults-file="$MYSQL_CNF" --backup --target-dir=$BACKUP_DIR/$BACKUP_FILE \
			$INCREMENT
		--extra-lsndir=$BACKUP_LSNDIR/"
	show_log $CMD
	$CMD 1>> $LOG_FILE 2>&1
	
	if [ "$BACKUP_TYPE" != "increment" ]; then
		# 得到数据库备份列表
		local DBLIST=`ls -p $MYSQL_DATADIR | grep / | tr -d /`

		if [ "$MYSQL_PASS" != "" ];then
			CONNECT_PASS="-p $MYSQL_PASS"
		fi

		#开始备份
		for dbname in $DBLIST
		do
			# 排除mysql高版本的schema数据库
			if [ "$dbname" == "performance_schema" ]; then
				continue
			fi
			# 备份数据库
			show_log "Backup myisam $dbname ... "
			CMD="$BACKUP_BIN/mysqlhotcopy -u $MYSQL_USER \
					 $CONNECT_PASS \
					 -P $MYSQL_PORT \
					 -S $MYSQL_SOCKET \
					 --addtodest -q \
					 $dbname
					 $BACKUP_DIR/$BACKUP_FILE"
			$CMD 1>> $LOG_FILE 2>&1
		done
	fi

	# 再保留最后的lsn到日志目录
	cp $BACKUP_DIR/$BACKUP_FILE/xtrabackup_checkpoints $BACKUP_LOG/$BACKUP_FILE/

	# 备份my.cnf
	cp $MYSQL_CNF $BACKUP_DIR/$BACKUP_FILE/

# 增加还原脚本
cat > $BACKUP_DIR/$BACKUP_FILE/setup.sh <<EOF
#!/bin/bash
xtrabackup --defaults-file=./my.cnf --prepare --target-dir=./
xtrabackup --defaults-file=./my.cnf --prepare --target-dir=./
chown -R mysql.mysql ./
rm -f xtrabackup_*
rm my.cnf
rm setup.sh
EOF
	chmod +x $BACKUP_DIR/$BACKUP_FILE/setup.sh

	# 检查错误
	check_fail "error"
	check_fail "errno"
	check_fail "failed"
	check_fail "denied"

	# 打包
	show_log "Start tar && zip dir"
	tar zcf $BACKUP_DIR/$BACKUP_FILE.tar.gz  -C $BACKUP_DIR $BACKUP_FILE
	rm -rf $BACKUP_DIR/$BACKUP_FILE

	show_log "tarzip size "`du -sh $BACKUP_DIR/$BACKUP_FILE.tar.gz |awk '{print $1}'`
	show_log "Database backup mysql success!"
}

# 检查是否有错误
function check_fail
{
	error=`grep -i $1 $LOG_FILE|grep -v Copying`
	if [ "$error" != "" ]; then
		show_log "[ERROR] Backup error ,please read log $LOG_FILE"
		exit -1
	fi
}

# 判断硬盘空间状况
function disk_space
{
	local data_size=`du  -s $MYSQL_DATADIR | awk '{print $1}'`
	data_size=$(awk "BEGIN{printf \"%d\",$data_size*1.25}")
	
	local disk_size=`df | grep data | awk '{print $4}'`
	if [ "$disk_size" == "" ]; then
		return
	fi

	#空闲少，报错退出
	if [[ $disk_size -lt $data_size ]] ; then
		show_log "[WARN] Do not have enough space to mysql backup, exit"
		exit -1
	fi
}

# 传输
function sync_clear
{
	local SLEEP_TIME=$(expr $(/usr/bin/hexdump -n4 -e\"%u\" /dev/urandom) % 10800)

	# 为了防止同时传输数据加上随机数
	show_log "Sleep $SLEEP_TIME seconds"
	sleep $SLEEP_TIME

	# 判断文件存在
	if [ ! -f $BACKUP_DIR/$BACKUP_FILE.tar.gz ]; then
		show_log "[ERROR] $BACKUP_DIR/$BACKUP_FILE.tar.gz not found"
		exit -1
	fi

	# 重命名
	SQL_MD5=`md5sum $BACKUP_DIR/$BACKUP_FILE.tar.gz |awk '{print $1}'`
	SQL_NAME_WITH_MD5="mysql-${MYSQL_PORT}-$(date +"%Y%m%d")_${BACKUP_SUFFIX}_${SQL_MD5}.tar.gz"
	cd  $BACKUP_DIR && mv $BACKUP_FILE.tar.gz $SQL_NAME_WITH_MD5

	#1传输
	local count="1"
	local op=`date "+%s"`
	while :
	do
		show_log "Begin to rsync the ${SQL_NAME_WITH_MD5} to $BACK_UP_SERVER::$SYNC_MODULE"
		rsync -av $BACKUP_DIR/$SQL_NAME_WITH_MD5 $SYNC_USER@$BACK_UP_SERVER::$SYNC_MODULE/${MY_IP}/  1>> $LOG_FILE 2>&1
		if [ $? -eq 0 ]
		then
			show_log "Rsync $SQL_NAME_WITH_MD5 successfully"
			break
		else
			show_log "[WARN] rsync $SQL_NAME_WITH_MD5 to $BACK_UP_SERVER failed, will retry"
			if [ $count = 5 ] ; then
				show_log "[ERROR] rsync error, exit"
				exit 1
			else
				((count++))
			fi
		fi
	done
			
	show_log "Rsync finish"
	local ed=`date "+%s"`
	local time_sec=`expr $[${ed} -${op}]`
	show_log "USE TIME_RSYNC ${time_sec} seconds "

	# 清理文件
	if [ "$BACKUP_SYNC" == "clean" ]; then
		show_log "Clean all files"
		cd ${BACKUP_DIR} && rm -rf *
	else
		auto_clean $AUTO_CLEAN_DAY
	fi
}

# 检查文件存在
function check_file
{
	if [ ! -e $1 ]; then
		show_log "[ERROR] $1 not found!"
		exit -1
	fi
}

# 清理几天前的数据
function auto_clean
{
	if [ "$1" == "" ]; then
		return
	fi

	show_log "Clean mysql backup dir $BACKUP_DIR gt $1 days"
	find $BACKUP_DIR -type f -mtime +$1 -exec rm -f {} \;
}

# 分析参数
parse_opt "$@"

# 默认配置
MYSQL_USER="root"
MYSQL_PORT=`grep -i '^port' $MYSQL_CNF| awk -F = '{print $2}'|sed s/\ //g|uniq|head -n 1`
MYSQL_SOCKET=`grep -i '^socket' $MYSQL_CNF| awk -F = '{print $2}'|sed s/\ //g|uniq|head -n 1`
MYSQL_PASS=`grep -i '^password' $MYSQL_CNF| awk -F = '{print $2}'|sed s/\ //g|uniq|head -n 1`
MYSQL_DATADIR=`grep -i '^datadir' $MYSQL_CNF| awk -F = '{print $2}'|sed s/\ //g|head -n 1`

BACKUP_DIR=$BACKUP_ROOT/$MYSQL_PORT
BACKUP_LSNDIR=$BACKUP_ROOT/${MYSQL_PORT}_lsn
BACKUP_FILE=`date "+%Y-%m-%d"`"_$BACKUP_SUFFIX"
LOG_FILE=$BACKUP_LOG/$BACKUP_FILE/backup_`date "+%H%M%S"`.log

# 创建目录
mkdir -p $BACKUP_DIR/$BACKUP_FILE
mkdir -p $BACKUP_LOG/$BACKUP_FILE
mkdir -p $BACKUP_LSNDIR

# 检查文件
check_file $MYSQL_CNF
check_file $MYSQL_DATADIR
if [ "$MYSQL_DATADIR" == "" ]; then
	show_log "[ERROR] datadir is empty!"
	exit -1
fi

# 检查版本
version=`$MYSQL_BIN/mysql -e "SHOW VARIABLES LIKE 'version'"|grep version|awk '{print $2}'`
innodb_version=`$MYSQL_BIN/mysql -e "SHOW VARIABLES LIKE 'innodb_version'"|grep innodb_version|awk '{print $2}'`

if [ "`echo $version|grep ^5.0`" != "" ]; then
	xtrabackup="$BACKUP_BIN/xtrabackup_51";
fi

if [ "`echo $version|grep ^5.1`" != "" ]; then
	xtrabackup="$BACKUP_BIN/xtrabackup_51";
	if [ "`echo $innodb_version|grep ^1.0`" != "" ]; then
		xtrabackup="$BACKUP_BIN/xtrabackup";
	fi
fi

if [ "`echo $version|grep ^5.2`" != "" ]; then
	xtrabackup="$BACKUP_BIN/xtrabackup";
fi

if [ "`echo $version|grep ^5.3`" != "" ]; then
	xtrabackup="$BACKUP_BIN/xtrabackup";
fi

if [ "`echo $version|grep ^5.5`" != "" ]; then
	xtrabackup="$BACKUP_BIN/xtrabackup_55";
fi

disk_space
backup

if [ "$BACKUP_SYNC" == "no" ]; then
	auto_clean $AUTO_CLEAN_DAY
	exit 1
fi

MY_IP=$(/sbin/ip ad sh | grep inet | grep -v "scope host lo"|egrep  -v "eth.:" | grep "\<10\." | awk '{print $2}' |head -n 1| xargs dirname)

BACK_UP_SERVER="10.30.35.56"
sync_clear
exit 1

#MY_IP_2=`echo $MY_IP | awk -F '.' '{print $2}'`
#case $MY_IP_2 in
#51)
#	BACK_UP_SERVER="10.51.34.46"
#	sync_clear
#	;;
#22)
#	BACK_UP_SERVER="10.30.38.111"
#	sync_clear
#	;;
#30)
#	BACK_UP_SERVER="10.22.222.51"
#	sync_clear
#	;;
#esac

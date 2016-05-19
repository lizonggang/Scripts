#!/bin/bash
##################################全局#####################################
#定义时间变量#
TIME=`date +%F_%T`
DAY=`date +%F`
#定义本脚本去除.sh后的名称####
SCRIPT_NAME=`basename ${0%.*}`
#根据本脚本的名称自动定日志名，如脚本叫run.sh,日志会变成run_${TIME}.log
LOG_NAME="${SCRIPT_NAME}_${TIME}.log" 
#定义输出日志的路径为/操作用户家目录/shell/log/,并预建立#####
LOG_PATH="${HOME}/shell/log/${SCRIPT_NAME}/"
mkdir -p ${LOG_PATH} || exit 1
#定义程序目录
DATA_PATH="/data/" 
#定义/data/repos/目录,并预建立##
REPOS_PATH="/data/repos/"
mkdir -p ${REPOS_PATH} || exit 1
###############################ftp##########################################
#定义ftp服务器的ip地址
FTP_IP="10.248.30.129"
#定义ftp服务器上包存放的位置#
FTP_PATH="/version/"
#定义ftp服务器的用户名#####需要自定义#####
FTP_USER="esanguo"
#定义ftp服务器的密码#####需要自定义#####
FTP_PASS="vTL2IheRKn3iIeXa"
#定义MD5文件名称
PACK_MD5_NAME="MD5.txt"
#定义下载文件文件夹目录,并预建立#####
PACKAGE_PATH="/data/package/${DAY}/"
mkdir -p ${PACKAGE_PATH} || exit 1
####################################新服###################################
#定义读取的服务器信息list文件名
LIST="/root/shell/list"
SERVER_LIST="/root/SERVER_LIST"
#定义安装包所在存储的IP,放在case里
#BACKUP_IP="10.30.34.209"
#定义安装包所在存储的目录##需要自己定义
INSTALL_PACKAGE_PATH="/data/server_install_package/sg_server_install_package/"
#定义拿取游戏资源的服务器IP###需要自己定义 放case里
#GAME_RESOURCE_IP="10.22.222.31"
#定义服务器上key所在的目录
LICENSE_PATH="/data/license/"
#定义ftp上存放license的目录
FTP_LICENSE_PATH="/license"
#游戏数据库名称####需要自己定义
GAMEDB_NAME="wardb3"
#主从信息
URL_SLAVE="http://yw.data.io8.org/data/slavelist.txt"
URL_MASTER="http://yw.data.io8.org/data/masterlist.txt"
#######################################脚本############################
BACK_UP_DIR="/data/SG/"
MERGE_TOOLS_PATH="/data/server_install_package/sg_merge_server_install/"
INSTALL_PACKAGE="SG_WEB_SERVER_INSTALL.tgz"
INSTALL_PACKAGE_MD5="SG_WEB_SERVER_INSTALL_MD5"
ANNEX_PATH="D:\\merge_tools\\"
OPEN_SQL="${ANNEX_PATH}merge_cleanDB.sql"
#游戏数据库名称
GAMEDB_NAME="wardb3"
GAMEDB_LOG="wardb3_log"
#游戏数据库用户名
GAMEDB_USER="sa"
#游戏数据库密码
M_PW="xbsgadmin"
#本地ip
LOCAL_IP=$(/sbin/ip a|grep inet|grep -v :|grep -E '172\.|192\.|10\.'|awk '{print $2}'|xargs dirname)


#回报函数
function REPORT
{   
	echo -e "[`date +%F-%H-%M-%S`] $1" | tee -a ${LOG_PATH}${LOG_NAME}
	[ $# -eq 2 ] && exit 1 || return 0
}
#Extension of REPORT，报错 & 退出
function REPORTWARN
{
	REPORT "[WARNING] $1" 1
}
#Extension of REPORT，提示信息
function REPORTINFO
{
	REPORT "[INFO] $1"
}
#本机服务器字符集的初始化
function INIT_VIMRC
{
! grep -q "fileencodings=ucs-bom,utf-8,cp936" /etc/vimrc && echo "set fileencodings=ucs-bom" >>/etc/vimrc 
! grep -q "fileencoding=utf-8" /etc/vimrc && echo "set fileencoding=utf-8" >>/etc/vimrc 
! grep -q "encoding=cp936" /etc/vimrc && echo "set encoding=cp936" >>/etc/vimrc 
}
#检测函数变量是否为空
function CHECK_VARIABLES
{
	#函数用法：CHECKVARIABLES  变量1  变量2 变量3
	local I="$*"
	for VAR in $I
	do
		eval Z_VAR='$'${VAR}
		[ -z "${Z_VAR}" ] && REPORTWARN "\$${VAR} is null"
	done
}
#正式操作前，再询问一次，是否需要继续，得到肯定回复后，然后sleep 8秒，8秒后开始
function ASK_AND_CONFIRM
{
REPORTINFO "you'd better check you choose is right,if ok please input Y,else input other"
read A
case ${A} in
y|Y)
	REPORTINFO "wait 5 second,if you change you mind please press ctrl+c "
	sleep 8
	REPORTINFO "1 2 3 GO GO GO,Good luck"
	;;
*)
	REPORTWARN "now we exit the shell script!"
	;;
esac
}
#指纹重建
function KNOWN_HOST_REBUILD 
{
[ ! -e /root/.ssh/known_hosts ] && mkdir ~/.ssh/ && touch ~/.ssh/known_hosts
local KNOWN_HOST="$*"
local i
for i in $KNOWN_HOST
do
	#删除原有指纹#
	sed -i "/^${i}\>/d" ~/.ssh/known_hosts
	#自动回答yes#
	ssh -q -oStrictHostKeyChecking=no $i ":"
	[[ $? -ne 0 ]] && REPORTWARN "KNOWN_HOST_REBUILD:$i know host rebuild fail,maybe the server connect error"
done
}
#重建win指纹
function KNOWN_HOST_REBUILD_WIN {
#确保本机存在known_hosts列表
[ ! -e /root/.ssh/known_hosts ] && mkdir ~/.ssh/ && touch ~/.ssh/known_hosts
local KNOWN_HOST="$*"
local i
for i in $KNOWN_HOST
do
	#删除原有指纹#
	sed -i "/^${i} /d" ~/.ssh/known_hosts
	#自动回答yes#
	ssh -q -oStrictHostKeyChecking=no administrator@${i} ":"
	[[ $? -ne 0 ]] && REPORTWARN "KNOWN_HOST_REBUILD_WIN:$i know host rebuild fail,maybe the server connect error"
done
}

#有本机、A机、B机 三台机器，需要从本机执行 scp A B
#此时必须在建立他们三方的指纹
#本机-A 本机-B A-B B-A
#此模块与KNOWN_HOST_REBUILD 模块共同使用，因为取得A B双方指纹的前提是已经在本机建立了AB指纹
#使用方法：KNOWN_HOST_FROM_TO_REBUILD IPA ipB
function KNOWN_HOST_FROM_TO_REBUILD
{
#确保函数最后带的是两个IP
[[ $# -eq 2 ]] || REPORTWARN "function use error,check it"
#定义互相建立指纹的ip
  local FROM_IP=$1
  local TO_IP=$2
#分别获取A B 在本机knowhosts 中的key。
  local FROM_RSA=`grep -w "^${FROM_IP}" /root/.ssh/known_hosts | head -n1`
  local TO_RSA=`grep -w "^${TO_IP}" /root/.ssh/known_hosts | head -n1`
#判断known_hosts 是否存在，如果不存在建立
  ssh  ${FROM_IP} "[ ! -e /root/.ssh/known_hosts ] && mkdir /root/.ssh/ && touch /root/.ssh/known_hosts"
  #ssh  ${TO_IP} "[ ! -e /root/.ssh/known_hosts ] && mkdir /root/.ssh/ && touch /root/.ssh/known_hosts"
#将A、B 机器的指纹放到他们各自的known_hosts 中
  #ssh ${TO_IP} "sed -i '/^${FROM_IP} /d' /root/.ssh/known_hosts
  #echo ${FROM_RSA} >> /root/.ssh/known_hosts"
  ssh ${FROM_IP} "sed -i '/^${TO_IP} /d' /root/.ssh/known_hosts 
  echo ${TO_RSA} >> /root/.ssh/known_hosts
   "
}

#清理本组/data/下数据scribe、license目录不清除 用法：函数名 IP1 IP2 IP3.......
function CLEAR_DIR 
{
#清空/data/目录下除scribe目录外的所有文件
local I="$*"
for i in ${I}
do
  ssh ${i} "cd ${DATA_PATH:-123456} &&
			ls | egrep -v \"scribe|license\"  | xargs rm -rf
			mkdir -p ${REPOS_PATH}"
done
}
#在执行脚本的服务器上建立PID文件，文件内部为本脚本执行的PID号
function CREATE_PID_FILE
{
local PID=$$
local SCRIPT_PID="${REPOS_PATH}${SCRIPT_NAME}.pid"
echo ${PID} > ${SCRIPT_PID} || REPORTWARN "something wrong with creating pid file"
chattr +i  ${SCRIPT_PID}
}
# 删除服务器上的PID 文件
function DELETE_PID_FILE
{
if [[ $# -ne 0 ]] && [[ $1 == "FORCE" ]] 
then
	local SCRIPT_PID="*.pid"
else
	local SCRIPT_PID="${REPOS_PATH}${SCRIPT_NAME}.pid"
fi
find ${REPOS_PATH} -name "$SCRIPT_PID"  -exec chattr -i {} \; -exec rm -f {} \;  || REPORTWARN "something wrong whith deleteing $SCRIPT_PID "
}
#	检查pid文件，要加ip
function CHECK_SCRIPT_RUNNING
{
local SCRIPT_PID="${REPOS_PATH}${SCRIPT_NAME}.pid"
local ip="$*"
for i in ${ip}
do
	#假如PID文件存在，检测进程是否存在，
	if ssh ${i} "test -f ${SCRIPT_PID}" 
	then	
		REPORINFO "PID file is exist"
		#检测PID文件是否为空
		local PID=`ssh ${i} "cat ${SCRIPT_PID}"` 
		if [[ -z ${PID} ]] 
		then
			REPORTWARN "the pid file is empty in ${i}"
		else
			#如果PID文件存在进程号，检测进程是否存在
			REPORTINFO "the process pid is `cat ${SCRIPT_PID}`"
			if ssh ${i} "ps --pid ${PID}" | grep -v grep| grep -q ${SCRIPT_NAME} 
			then
				#### PID file存在,进程存在#
				REPORTWARN "the script has running already"      
			else
				#### PID file存在,进程不存在#
				REPORTWARN "the script not running"   
			fi
		fi
		REPORTWARN "check error,exist"
	fi
done
}
#拿取license，用法GET_LICENSE 需要拿取的IP1 IP2 IP3 ...... 本函数依赖domain本组服务器域名这个变量
function GET_LICENSE
{
[[ $# -ge 1 ]] || REPORTWARN "function use error,please read the function explain"
local I="$*"
for ip in ${I}
do
	REPORINFO "now we download the license"
	ssh ${ip} "mkdir -p ${LICENSE_PATH} && wget --user=${FTP_USER} --password=${FTP_PASS} ftp://${FTP_IP}${FTP_LICENSE_PATH}/${}${ip}.lic -P ${LICENSE_PATH}"
	ssh ${ip} "scp -rp ${LICENSE_PATH}${ip}.lic ${LICENSE_PATH}imop.lic && scp -rp ${LICENSE_PATH}${ip}.lic /root/"
	ssh ${ip} "[[ -s ${LICENSE_PATH}imop.lic ]]" || REPORTWARN "${ip} download license fail,maybe the licese not create or key not upload"
done
}

######################################脚本函数##########################################

#是否在线检查
function MERGE_TYPE_CHECK
{
	[ $LOCAL_IP = $NEW_WEB_IP ] || REPORTWARN "MERGE_TYPE_CHECK:local ip err"
	[[ $# -eq 1 ]] || REPORTWARN "MERGE_TYPE_CHECK:option err"
	local I=$1
	if [[ ${MERGE_TYPE} != ${I} ]]
	then
		REPORTWARN "MERGE_TYPE_CHECK:The input TYPE ${TYPE} is not same as the MERGE_TYPE in LIST"
	fi
}
#以检查连接的方式检查是否为线上服
function ONLINE_CHECK
{
#游戏程序检查
#用法 ONLINE_CHECK [run|stop] ip1 ip2 ip3...
local type=$1
REPORTINFO "ONLINE_CHECK:start to check server $type"
echo $type |grep -iqwE 'run|stop' || REPORTWARN "ONLINE_CHECK:option err"
shift
local CMD="$*" 
for i in ${CMD}
do
	
	case $type in
		stop)
			local status_num=$(ssh $i "echo \$[ \$(netstat -antp|grep -w java|grep -wc 1433) + \$(/data/jdk/bin/jps |grep -Ewic \"resin|chatserver|watchdogManager\") ]")
			[ $status_num -ne 0 ] && REPORTWARN "ONLINE_CHECK:$i GAME process is running...check it!!!"
			return 0
		;;
		run)
			local status_num=$(ssh $i "echo \$(/data/jdk/bin/jps |grep -Ewic \"resin|chatserver|watchdogManager\")")
			[ $status_num -lt 3 ] && REPORTWARN "ONLINE_CHECK:$i num. of GAME process err"
			return 0
		;;
		*)
			REPORTWARN "ONLINE_CHECK:option err"
		;;
	esac
done
REPORTINFO "ONLINE_CHECK:check server $type done"
}
#web机修改合服配置文件，上传到db上
function MODIFY_AND_UPDATE
{
	REPORTINFO "MODIFY_AND_UPDATE:FUNCTION MODIFY_AND_UPDATE START"
	for i in `seq 1 5`
	do
	eval local IP="$"SOURCE_WEB_IP$i
	[ "$IP" ] || break
	eval SERVER_NAME$i=$(ssh $IP "awk -F'\"' '/servername/{print \$4}' /data/applib/serverConsConf.xml")
	done
	
	case ${TYPE} in
		a)
			case ${LANG_VERSION} in
				zh_CN)
				[ "${MERGE_DB_IP}" ] || REPORTWARN "MODIFY_AND_UPDATE:MERGE_DB_IP is null, plz check"
				[ "${MERGE_WEB_IP}" ] || REPORTWARN "MODIFY_AND_UPDATE:MERGE_WEB_IP is null, plz check"
				local DST_DB_IP=${MERGE_DB_IP}
				local DST_WEB_IP=${MERGE_WEB_IP}
				;;
				zh_TW)
				[ "${MERGE_TW_DB_IP}" ] || REPORTWARN "MODIFY_AND_UPDATE:MERGE_TW_DB_IP is null, plz check"
				[ "${MERGE_TW_WEB_IP}" ] || REPORTWARN "MODIFY_AND_UPDATE:MERGE_TW_WEB_IP is null, plz check"
				local DST_DB_IP=${MERGE_TW_DB_IP}
				local DST_WEB_IP=${MERGE_TW_WEB_IP}
				;;
				en_US)
				[ "${MERGE_EN_DB_IP}" ] || REPORTWARN "INIT_EN:MERGE_EN_DB_IP is null, plz check"
				[ "${MERGE_EN_WEB_IP}" ] || REPORTWARN "INIT_EN:MERGE_EN_WEB_IP is null, plz check"
				local DST_DB_IP=${MERGE_EN_DB_IP}
				local DST_WEB_IP=${MERGE_EN_WEB_IP}
				;;
				*)
				REPORTWARN "MODIFY_AND_UPDATE:server LANGVERSION err, plz check"
				;;
			esac
		;;
		1)
			[ "${NEW_DBM_IP}" ] || REPORTWARN "MODIFY_AND_UPDATE:NEW_DBM_IP is null, plz check"
			[ "${NEW_WEB_IP}" ] || REPORTWARN "MODIFY_AND_UPDATE:NEW_WEB_IP is null, plz check"
			local DST_DB_IP=${NEW_DBM_IP}
			local DST_WEB_IP=${NEW_WEB_IP}
		;;
		*)
		REPORTWARN "MODIFY_AND_UPDATE:\$TYPE err, plz check"
		;;
	esac
		REPORTINFO "MODIFY_AND_UPDATE:DST_DB_IP = ${DST_DB_IP}"
		REPORTINFO "MODIFY_AND_UPDATE:DST_WEB_IP = ${DST_WEB_IP}"	
		REPORTINFO "MODIFY_AND_UPDATE:del old_merge_tools"
		rm -rf ${REPOS_PATH}merge_tools
		ssh administrator@${DST_DB_IP} "dir merge_tools && rd merge_tools /s/q"  >/dev/null 2>&1
		ssh administrator@${DST_DB_IP} "dir d:\merge_tools && rd d:\merge_tools /s/q"  >/dev/null 2>&1
		REPORTINFO "MODIFY_AND_UPDATE:get new_merge_tools"
		scp -r ${BACKUP_IP}:${MERGE_TOOLS_PATH} ${REPOS_PATH} >/dev/null 2>&1 || REPORTWARN "get merge_tool fail" 
		REPORTINFO "MODIFY_AND_UPDATE:start to modify file of config"
		cd ${REPOS_PATH}merge_tools/config
		MERGE_CONFIG ${SOURCE_DB_IP1} ${SOURCE_WEB_IP1} ${STR_SERVER1} ${SERVER_NAME1} 1
		MERGE_CONFIG ${SOURCE_DB_IP2} ${SOURCE_WEB_IP2} ${STR_SERVER2} ${SERVER_NAME2} 2
		[[ ${SOURCE_DB_IP3} = "" ]] && rm -f source_3.properties || MERGE_CONFIG ${SOURCE_DB_IP3} ${SOURCE_WEB_IP3} ${STR_SERVER3} ${SERVER_NAME3} 3
		[[ ${SOURCE_DB_IP4} = "" ]] && rm -f source_4.properties || MERGE_CONFIG ${SOURCE_DB_IP4} ${SOURCE_WEB_IP4} ${STR_SERVER4} ${SERVER_NAME4} 4
		[[ ${SOURCE_DB_IP4} = "" ]] && rm -f source_5.properties || MERGE_CONFIG ${SOURCE_DB_IP5} ${SOURCE_WEB_IP5} ${STR_SERVER5} ${SERVER_NAME5} 5
		scp databeaseconfig.xml${SOURCE_NUM} databeaseconfig.xml || REPORTWARN "MODIFY_AND_UPDATE:change modify databeaseconfig.xml fail"
		ls databeaseconfig.xml[2-5] | xargs rm -f
		sed -i -e "/^dbip=/s#.*#dbip=${DST_DB_IP}#g" \
		-e "/^webip=/s#.*#webip=${DST_WEB_IP}:6001#g" destination.properties || \
		REPORTWARN "MODIFY_AND_UPDATE:modify destination.properties fail"
		unix2dos * >/dev/null 2>&1 
		REPORTINFO "MODIFY_AND_UPDATE:start to update merge_tools"
		cd ${REPOS_PATH}
		scp -r merge_tools administrator@${DST_DB_IP}: >/dev/null 2>&1 && \
		ssh administrator@${DST_DB_IP} "xcopy /e merge_tools ${ANNEX_PATH}" >/dev/null 2>&1
		[ $? -ne 0 ] && REPORTWARN "MODIFY_AND_UPDATE:put merge_tools err, plz check"
		REPORTINFO "MODIFY_AND_UPDATE:FUNCTION MODIFY_AND_UPDATE DONE"
}
#db服务器安装准备
function INSTALL_DB_SERVER
{
#因为是windows，所以只能准备好东西，去windows上装
	REPORTINFO "INSTALL_DB_SERVER:Preparing for Installation db, plz wait"
	local filter
	local DOMAIN=$(echo ${NEW_DOMAIN} |awk -F. '{print $(NF-1)"."$NF}')
	while :
	do
		if ! [ "$filter" ]
		then
			local dir=$(ssh ${BACKUP_IP} "find /data/SG -type d -name \"*${DOMAIN}*\" |xargs du -h|grep -w '^[0-9]*G' |sort -n|awk 'NR==1{print \$NF}'")
		else
			local dir=$(ssh ${BACKUP_IP} "find /data/SG -type d -name \"*${DOMAIN}*\" |xargs du -h|grep -w '^[0-9]*G' |sort -n|grep -Ewv '$(echo ${filter}|sed -e 's#^|##' -e 's#|$##')'|awk 'NR==1{print \$NF}'")
		fi
		local file=$(ssh ${BACKUP_IP} "ls -lth $dir|awk 'NR==2{print \$NF}'")
		if [ "${file%.*}" = $(date +%y-%m-%d) ] 
		then
			break 
		else
			filter="$(echo $dir|xargs basename)|${filter}"
		fi
	done
	[ "$dir" ] || REPORTWARN "INSTALL_DB_SERVER:get backup_file err"
	local backup_name=$(ssh ${BACKUP_IP} "rar vb $dir/$file")
	ssh ${BACKUP_IP} "
		md5sum ${INSTALL_PACKAGE_PATH}DB/SG_DB_SERVER_INSTALL.tgz |awk '{print \$1}' |grep -qw \$(cat ${INSTALL_PACKAGE_PATH}DB/SG_DB_SERVER_INSTALL_MD5 |awk '{print \$1}') || exit 1
		mkdir -p ${INSTALL_PACKAGE_PATH}DB/${NEW_WEB_IP}/
		rm -rf ${INSTALL_PACKAGE_PATH}DB/${NEW_WEB_IP}/*
		tar zxf ${INSTALL_PACKAGE_PATH}DB/SG_DB_SERVER_INSTALL.tgz -C ${INSTALL_PACKAGE_PATH}DB/${NEW_WEB_IP}/ || exit 1
		mkdir -p ${INSTALL_PACKAGE_PATH}DB/${NEW_WEB_IP}/software/restore
		rm -rf ${INSTALL_PACKAGE_PATH}DB/${NEW_WEB_IP}/software/restore/*
		cp $dir/$file ${INSTALL_PACKAGE_PATH}DB/${NEW_WEB_IP}/software/restore/ || exit 1
		cd ${INSTALL_PACKAGE_PATH}DB/${NEW_WEB_IP}/software/sg_install_db
		dos2unix install.txt >/dev/null 2>&1
		sed -i -e '/servicename/s#\$#${NEW_DOMAIN%%.*}#g' -e '/backuppath/s#\$#D:\\\\software\\\\restore\\\\$(echo ${backup_name}|sed 's#/#\\\\#g')#g' install.txt || exit 1
		unix2dos install.txt >/dev/null 2>&1
		chown -R backup.backup ${INSTALL_PACKAGE_PATH}DB/${NEW_WEB_IP}/software/
	"
	[ $? -ne 0 ] && REPORTWARN "INSTALL_DB_SERVER:modify db_config err"
	REPORTINFO "请在windows上先解压d:\software\restore\\$backup_name，选择解压到当前目录即可，再执行安装脚本"
	REPORTINFO "INSTALL_DB_SERVER:the Preparation of install db done, plz install on windows"
}
#获取合服信息
function GET_MERGE_INFO
{
	if [ -s $LIST ]
	then
		#合服共有变量
		SOURCE_NUM=$(awk '{print $4}' $LIST)
		echo $SOURCE_NUM|grep -qwi "[1-5]" || REPORTWARN "GET_MERGE_INFO:SOURCE_NUM err" 
		MERGE_TYPE=$(awk '{print $6}' $LIST)
		echo $MERGE_TYPE|grep -qwi "[01]" || REPORTWARN "GET_MERGE_INFO:MERGE_TYPE err" 
		LANG_VERSION=$(awk '{print $5}' $LIST)
		case $LANG_VERSION in
			zh_CN)
				BACKUP_IP="10.30.34.209"
			;;
			zh_TW)
				BACKUP_IP="10.51.33.46"
			;;
			en_US)
				BACKUP_IP="10.30.34.209"
			;;
			*)
				REPORTWARN "GET_MERGE_INFO:LANG_VERSION err"
			;;
		esac
		KNOWN_HOST_REBUILD $BACKUP_IP
		#合服source_domain
		SOURCE1_DOMAIN=$(awk '{print $7}' $LIST)
		SOURCE2_DOMAIN=$(awk '{print $9}' $LIST)
		awk '{print $11}' $LIST|grep -iwq "null" || SOURCE3_DOMAIN=$(awk '{print $11}' $LIST)
		awk '{print $13}' $LIST|grep -iwq "null" || SOURCE4_DOMAIN=$(awk '{print $13}' $LIST)
		awk '{print $15}' $LIST|grep -iwq "null" || SOURCE5_DOMAIN=$(awk '{print $15}' $LIST)
		case $TYPE in
			0)
				#SERVER_LIST的格式检查
				if [ -s ${SERVER_LIST} ]
				then
					if	! { [ `cat ${SERVER_LIST}|wc -l` -eq 8 ] && \
						[ `grep -wci "^source[1-$SOURCE_NUM}]" ${SERVER_LIST}` -eq ${SOURCE_NUM} ] && \
						[ `grep -iwc "^merge" ${SERVER_LIST}` -eq 1 ] && [ `grep -iwc "^domain" ${SERVER_LIST}` -eq 1 ] && \
						[ `grep -iwc "^#name" ${SERVER_LIST}` -eq 1 ] 
						}
					then
						REPORTWARN "GET_MERGE_INFO:${SERVER_LIST} format err"
					fi
				else
					REPORTWARN "GET_MERGE_INFO:${SERVER_LIST} not exist or is null"
				fi
				#source ip 提取
				for i in `seq 1 ${SOURCE_NUM}`
				do
					#测试合服source_web_ip
					eval SOURCE${i}_WEB=$(awk '/^source'"$i"'/{print $3}' $SERVER_LIST)
					eval KNOWN_HOST_REBUILD '$'SOURCE${i}_WEB
					#正式合服source_db_ip
					eval SOURCE${i}_DB=$(awk '/^source'"$i"'/{print $2}' $SERVER_LIST)
					eval KNOWN_HOST_REBUILD_WIN '$'SOURCE${i}_DB
				done
				#正式合服新装的合服目标机
				NEW_DBM_IP=$(awk '/^merge/{print $2}' $SERVER_LIST)
				NEW_WEB_IP=$(awk '/^merge/{print $3}' $SERVER_LIST)
				NEW_DOMAIN=$(awk '/^domain/{print $2}' $SERVER_LIST)	
			;;
			1)
				#正式合服source_web_ip
				SOURCE1_WEB=$(awk '{print $8}' $LIST)
				SOURCE2_WEB=$(awk '{print $10}' $LIST)
				awk '{print $12}' $LIST|grep -iwq "null" || SOURCE3_WEB=$(awk '{print $12}' $LIST)
				awk '{print $14}' $LIST|grep -iwq "null" || SOURCE4_WEB=$(awk '{print $14}' $LIST)
				awk '{print $16}' $LIST|grep -iwq "null" || SOURCE5_WEB=$(awk '{print $16}' $LIST)
				for i in `seq 1 ${SOURCE_NUM}`
				do
					eval KNOWN_HOST_REBUILD '$'SOURCE${i}_WEB
				done
				#正式合服source_db_ip
				SOURCE1_DB=$(ssh $SOURCE1_WEB "awk -F'\"' '/DBIP/{print \$4}' /data/applib/serverConsConf.xml")
				SOURCE2_DB=$(ssh $SOURCE2_WEB "awk -F'\"' '/DBIP/{print \$4}' /data/applib/serverConsConf.xml")
				[ "$SOURCE3_WEB" ] && SOURCE3_DB=$(ssh $SOURCE3_WEB "awk -F'\"' '/DBIP/{print \$4}' /data/applib/serverConsConf.xml")
				[ "$SOURCE4_WEB" ] && SOURCE4_DB=$(ssh $SOURCE4_WEB "awk -F'\"' '/DBIP/{print \$4}' /data/applib/serverConsConf.xml")
				[ "$SOURCE5_WEB" ] && SOURCE5_DB=$(ssh $SOURCE5_WEB "awk -F'\"' '/DBIP/{print \$4}' /data/applib/serverConsConf.xml")
				for i in `seq 1 ${SOURCE_NUM}`
				do
					eval KNOWN_HOST_REBUILD_WIN '$'SOURCE${i}_DB
				done
				#正式合服新装的合服目标机
				NEW_DBM_IP=$(awk '{print $1}' $LIST)
				NEW_WEB_IP=$(awk '{print $2}' $LIST)
				NEW_DOMAIN=$(awk '{print $3}' $LIST)
			;;
			*)
			REPORTWARN "GET_MERGE_INFO:MERGE_TYPE err"
			;;
		esac
	else
		REPORTWARN "GET_MERGE_INFO:LIST is null or not exist"
	fi
	#根据域名选择服务器拿取游戏资源的ip，一般为本大区的1服
	case $(echo $NEW_DOMAIN|awk -F. '{print $(NF-1)}') in
		mop)
			GAME_RESOURCE_IP="10.30.34.61"
		;;
		renren)
			GAME_RESOURCE_IP="10.30.34.67"
		;;
		imop)
			GAME_RESOURCE_IP="10.51.32.33"
		;;
		hithere)
			GAME_RESOURCE_IP="10.51.33.63"
		;;
		*)
			REPORTWARN "GET_MERGE_INFO:DOMAIN type err"
		;;
	esac
	#KNOWN_HOST_REBUILD_WIN $NEW_DBM_IP
	KNOWN_HOST_REBUILD $NEW_WEB_IP
	KNOWN_HOST_REBUILD $GAME_RESOURCE_IP
	ALL_SOURCE_DB_IP="$SOURCE1_DB $SOURCE2_DB $SOURCE3_DB $SOURCE4_DB $SOURCE5_DB"
	ALL_SOURCE_WEB_IP="$SOURCE1_WEB $SOURCE2_WEB $SOURCE3_WEB $SOURCE4_WEB $SOURCE5_WEB"
	ALL_SOURCE_DOMAIN="$SOURCE1_DOMAIN $SOURCE2_DOMAIN $SOURCE3_DOMAIN $SOURCE4_DOMAIN $SOURCE5_DOMAIN "
	for i in $ALL_SOURCE_DB_IP
	do
	KNOWN_HOST_FROM_TO_REBUILD $BACKUP_IP $i
	done
}
#list合法性完整性检查
function CHECK_LIST
{
#检测变量是否为空
CHECK_VARIABLES LIST NEW_DBM_IP NEW_WEB_IP NEW_DOMAIN SOURCE_NUM LANG_VERSION MERGE_TYPE LOCAL_IP
{
	[ "$ALL_SOURCE_DB_IP" ] && [ "$ALL_SOURCE_WEB_IP" ] && [ "$ALL_SOURCE_DOMAIN" ]
} || REPORTWARN "CHECK_LIST: all ip is err"
for i in `seq 1 $SOURCE_NUM`
do
	CHECK_VARIABLES SOURCE${i}_DOMAIN
	CHECK_VARIABLES SOURCE${i}_DB
	CHECK_VARIABLES SOURCE${i}_WEB
done
#判断LIST是否为空
if ! [[ -s ${LIST} ]]
then
	REPORTWARN "LIST is null or not exist"
else
	#判断源服个数是否 大于等于2小于等于5，source数与合服组数是否一致
	local NUM=0
	for i in `seq 1 5`
	do
	[ "$(eval echo '$'SOURCE${i}_WEB)" ] && NUM=`expr $NUM + 1`
	done
	if ! { [[ ${NUM} -ge 2 ]] && [[ ${NUM} -le 5  ]] && [[ ${NUM} -eq ${SOURCE_NUM} ]] 
		}
	then
		REPORTWARN "CHECK_LIST:SOURCE_NUM is ${SOURCE_NUM}, not >=2  <=5"
	fi
	#目标域名与合并后域名是否匹配
	[[ ${SOURCE1_DOMAIN} = $(awk '{print $3}' $LIST) ]] || REPORTWARN "CHECK_LIST:SOURCE1_DOMAIN is not same as NEW_DOMAIN "
	[ $TYPE -ne $MERGE_TYPE ] && REPORTWARN "CHECK_LIST:TYPE is not same as MERGE_TYPE "
fi
}
#输出变量并等待
function ECHO_AND_ASK
{
echo "所有变量如下："|iconv -f utf-8 -t gbk
	cat <<eof
LOCAL_IP = $LOCAL_IP
SOURCE_NUM = $SOURCE_NUM
LANG_VERSION = $LANG_VERSION
MERGE_TYPE = $MERGE_TYPE
BACKUP_IP = $BACKUP_IP
GAME_RESOURCE_IP = $GAME_RESOURCE_IP
NEW_DBM_IP = $NEW_DBM_IP
NEW_WEB_IP = $NEW_WEB_IP
NEW_DOMAIN = $NEW_DOMAIN
ALL_SOURCE_DB_IP = $ALL_SOURCE_DB_IP
ALL_SOURCE_WEB_IP = $ALL_SOURCE_WEB_IP
ALL_SOURCE_DOMAIN = $ALL_SOURCE_DOMAIN
eof
	for i in `seq 1 ${SOURCE_NUM}`
	do
		eval echo SOURCE${i}_WEB = '$'SOURCE${i}_WEB
	done
	for i in `seq 1 ${SOURCE_NUM}`
	do
		eval echo SOURCE${i}_DB = '$'SOURCE${i}_DB
	done
	for i in `seq 1 ${SOURCE_NUM}`
	do
		eval echo SOURCE${i}_DOMAIN = '$'SOURCE${i}_DOMAIN
	done
	ASK_AND_CONFIRM
}
#数据灌入
function DATA_IMPORT
{
	
	[ $# -eq 1 ] || REPORTWARN "DATA_IMPORT:option err"
	echo $1 | grep -iwq "$(seq 1 $SOURCE_NUM)" || REPORTWARN "DATA_IMPORT:option err"
	local L=$1
	#存储上服务器对应的备份路径
	local back_up_dir
	#备份文件对应文件名，取一天前得备份包
	local back_up_file
	#rar包中的目录结构
	local server
	#rar包中的第一层目录
	local server_dir
	#rar包中的文件名
	local server_file
	eval local domain='$'SOURCE${L}_DOMAIN
	eval local dbip='$'SOURCE${L}_DB
	#restoresql路径
	local restoresql="/data/merge/restoresql_tmp/${dbip}/"
	[ $(ssh $BACKUP_IP "ls -ld ${BACK_UP_DIR}${domain%%.*}[^0-9a-Z]*|wc -l") -ne 1 ] && \
	REPORTWARN "DATA_IMPORT:get back_up_dir err"
	back_up_dir=$(ssh $BACKUP_IP "ls -ld ${BACK_UP_DIR}${domain%%.*}[^0-9a-Z]*|awk '{print \$NF}'")
	ssh $BACKUP_IP "ls ${back_up_dir}/\$(date +%y-%m-%d.rar)" >/dev/null 2>&1 || \
	REPORTWARN "DATA_IMPORT:get back_up_file err"
	back_up_file=$(ssh $BACKUP_IP "ls ${back_up_dir}/\$(date +%y-%m-%d.rar)"|xargs basename)
	server=$(ssh $BACKUP_IP "rar vb ${back_up_dir}/${back_up_file}")
	server_dir=$(echo $server|xargs dirname)
	server_file=$(echo $server|xargs basename)
	#上传db包到windows的d:\restore中
	REPORTINFO "DATA_IMPORT:start to update backup_file"
	ssh administrator@${dbip} "rd /s /q  d:\restore" >/dev/null 2>&1
	ssh administrator@${dbip} "mkdir d:\restore" >/dev/null 2>&1
	ssh $BACKUP_IP "cd $back_up_dir
	sftp administrator@$dbip << eof
	cd /D:/restore
	put ${back_up_file}
	bye
	eof" || {
	echo "${domain} ${dbip} err" >> ${LOG_PATH}log.tmp
	exit 1
	}
	ssh administrator@$dbip "dir d:\backup\backup\rar.exe > nul && d:\backup\backup\rar.exe x -o+ d:\restore\\${back_up_file} d:\restore" 
	[ $? -ne 0 ] && {
	echo "${domain} ${dbip} err" >> ${LOG_PATH}log.tmp
	exit 1
	}
	#生成restoresql并上传至db
	mkdir -p $restoresql
	rsync -aq --delete -e 'ssh' ${BACKUP_IP}:${MERGE_TOOLS_PATH}restore/ ${restoresql} && \
	md5sum ${restoresql}restore.sql |awk '{print $1}'|grep -w "$(cat ${restoresql}restore_md5|awk '{print $1}')"
	[ $? -ne 0 ] && {
	echo "${domain} ${dbip} err" >> ${LOG_PATH}log.tmp
	exit 1	
	}
	dos2unix ${restoresql}restore.sql >/dev/null 2>&1
	sed -i -e '/DISK/s#D:.*'\''#D:\\restore\\'"${server_dir}"'\\'"${server_file}"''\''#g' \
	-e 's#merge_db#m'"${L}"'_db#g' ${restoresql}restore.sql 
	[ $? -ne 0 ] && {
	echo "${domain} ${dbip} err" >> ${LOG_PATH}log.tmp
	exit 1
	}
	unix2dos ${restoresql}restore.sql >/dev/null 2>&1
	scp ${restoresql}restore.sql administrator@${dbip}:d://
	ssh administrator@${dbip} "rd /s /q d:\m${L}_db" >/dev/null 2>&1
	ssh administrator@${dbip} "mkdir d:\m${L}_db" >/dev/null 2>&1
	#恢复数据
	ssh administrator@${dbip} "sqlcmd -i \"d:\restore.sql\" -S localhost -U ${GAMEDB_USER} -P ${M_PW}"| \
	iconv -f GBK -t UTF-8 | \
	grep -q 'RESTORE DATABASE 成功处理'
	[ $? -ne 0 ] && {
	echo "${domain} ${dbip} err" >> ${LOG_PATH}log.tmp
	exit 1
	}
}
#初始化merge机的数据库，否则合服会失败
function INIT_DB
{
REPORTINFO "INIT_DB:FUNCTION INIT_DB START"
local DST_DB_IP=${NEW_DBM_IP}
REPORTINFO "INIT_DB:DST_DB_IP = ${DST_DB_IP}"
sleep 20
local op=`date "+%s"`
#远程执行清档sql
ssh administrator@${DST_DB_IP} " dir ${OPEN_SQL} && sqlcmd -i ${OPEN_SQL} -S localhost -U ${GAMEDB_USER} -P ${M_PW} -d ${GAMEDB_NAME}"  | grep "db clear successfully"
[ $? -ne 0 ] && REPORTWARN "INIT_DB:init_db err, plz check"

local ed=`date "+%s"`
local time_min=`expr $[${ed} - ${op}]`
REPORTINFO "INIT_DB:[TIME_ALL] USE TIME_ALL ${time_min} seconds"
REPORTINFO "INIT_DB:FUNCTION INIT_DB DONE"
}
#朽败配置文件
function MERGE_CONFIG
{
#MERGE_CONFIG DBIP WEBIP STR_SERVER SERVER_NAME
if [[ $# -eq 5 ]] && [[ $5 = [12345] ]]
then
	if cd ${REPOS_PATH}merge_tools/config
	then
		sed -i -e "/^dbip=/s#.*#dbip=${1}#g" \
		-e "/^webip=/s#.*#webip=${2}:6001#g" \
		-e "/symbol=/s#.*#symbol=${3}_#g" \
		-e "/serverName=/s#.*#serverName=${4}#g" source_${5}.properties || \
		REPORTWARN "MERGE_CONFIG:modify source_${5}.properties fail"
	else
		REPORTWARN "change dir ${REPOS_PATH}merge_tools/config failed"
	fi
else
	REPORTWARN "function use error,check it"
fi
}
#web机修改合服配置文件，上传到db上
function MODIFY_AND_UPDATE
{
	REPORTINFO "MODIFY_AND_UPDATE:FUNCTION MODIFY_AND_UPDATE START"
	for i in `seq 1 5`
	do
	eval local IP="$"SOURCE${i}_WEB
	[ "$IP" ] || break
	eval SERVER_NAME$i=$(ssh $IP "awk -F'\"' '/servername/{print \$4}' /data/applib/serverConsConf.xml")
	done
	local DST_DB_IP=$NEW_DBM_IP
	local DST_WEB_IP=$NEW_WEB_IP
	REPORTINFO "MODIFY_AND_UPDATE:DST_DB_IP = ${DST_DB_IP}"
	REPORTINFO "MODIFY_AND_UPDATE:DST_WEB_IP = ${DST_WEB_IP}"	
	REPORTINFO "MODIFY_AND_UPDATE:del old_merge_tools"
	rm -rf ${REPOS_PATH}merge_tools
	ssh administrator@${DST_DB_IP} "dir merge_tools && rd merge_tools /s/q"  >/dev/null 2>&1
	ssh administrator@${DST_DB_IP} "dir d:\merge_tools && rd d:\merge_tools /s/q"  >/dev/null 2>&1
	REPORTINFO "MODIFY_AND_UPDATE:get new_merge_tools"
	scp ${BACKUP_IP}:${MERGE_TOOLS_PATH}merge_tools.tgz ${REPOS_PATH} >/dev/null 2>&1 || REPORTWARN "MODIFY_AND_UPDATE:get merge_tool fail" 
	local lmd5=$(md5sum ${REPOS_PATH}merge_tools.tgz|awk '{print $1}')
	local md5=$(ssh ${BACKUP_IP} "cat ${MERGE_TOOLS_PATH}merge_tools_md5"|awk '{print $1}')
	[ $lmd5 != $md5 ] && REPORTWARN "MODIFY_AND_UPDATE:merge_tools md5 err"
	tar zxf ${REPOS_PATH}merge_tools.tgz -C ${REPOS_PATH} || REPORTWARN "MODIFY_AND_UPDATE:merge_tools Extract err"
	REPORTINFO "MODIFY_AND_UPDATE:start to modify file of config"
	cd ${REPOS_PATH}merge_tools/config
	MERGE_CONFIG ${SOURCE1_DB} ${SOURCE1_WEB} ${SOURCE1_DOMAIN%%.*} ${SERVER_NAME1} 1
	MERGE_CONFIG ${SOURCE2_DB} ${SOURCE2_WEB} ${SOURCE2_DOMAIN%%.*} ${SERVER_NAME2} 2
	[[ ${SOURCE3_DB} = "" ]] && rm -f source_3.properties || MERGE_CONFIG ${SOURCE3_DB} ${SOURCE3_WEB} ${SOURCE3_DOMAIN%%.*} ${SERVER_NAME3} 3
	[[ ${SOURCE4_DB} = "" ]] && rm -f source_4.properties || MERGE_CONFIG ${SOURCE4_DB} ${SOURCE4_WEB} ${SOURCE4_DOMAIN%%.*} ${SERVER_NAME4} 4
	[[ ${SOURCE5_DB} = "" ]] && rm -f source_5.properties || MERGE_CONFIG ${SOURCE5_DB} ${SOURCE5_WEB} ${SOURCE5_DOMAIN%%.*} ${SERVER_NAME5} 5
	scp databeaseconfig.xml${SOURCE_NUM} databeaseconfig.xml || REPORTWARN "MODIFY_AND_UPDATE:change modify databeaseconfig.xml fail"
	ls databeaseconfig.xml[2-5] | xargs rm -f
	sed -i -e "/^dbip=/s#.*#dbip=${DST_DB_IP}#g" \
	-e "/^webip=/s#.*#webip=${DST_WEB_IP}:6001#g" destination.properties || \
	REPORTWARN "MODIFY_AND_UPDATE:modify destination.properties fail"
	unix2dos * >/dev/null 2>&1 
	REPORTINFO "MODIFY_AND_UPDATE:start to update merge_tools"
	cd ${REPOS_PATH}
	scp -r merge_tools administrator@${DST_DB_IP}: >/dev/null 2>&1 && \
	ssh administrator@${DST_DB_IP} "xcopy /e merge_tools ${ANNEX_PATH}" >/dev/null 2>&1
	[ $? -ne 0 ] && REPORTWARN "MODIFY_AND_UPDATE:put merge_tools err, plz check"
	REPORTINFO "MODIFY_AND_UPDATE:FUNCTION MODIFY_AND_UPDATE DONE"
}
#执行merge合服脚本
function MERGE
{
#用法 MERGE num                          
#rem 参数 例：jre\bin\java -jar -Xmx1400m MergeServer.jar -console 1
#rem 1：撒城
#rem 2：停服
#rem 3：数据迁移以后的所有操作。如果数据迁移成功后报错，则适用此参数。（注意清目标库）
#rem 无：所有操作
REPORTINFO "MERGE:FUNCTION MERGE START"
	##清空日志之类的
	REPORTINFO "INIT_DB:FUNCTION INIT_DB START"
	local DST_DB_IP=${NEW_DBM_IP}
	REPORTINFO "INIT_DB:DST_DB_IP = ${DST_DB_IP}"
	ssh administrator@${DST_DB_IP} "dir ${ANNEX_PATH}log && del ${ANNEX_PATH}log\*.log" 
	[ $? -ne 0 ] && REPORTWARN "delete log err, plz check"
	printf "\e[33m\e[1m%s\e[0m : \e[31m\e[1m%s\e[0m\n" "请登录windows执行bat以进行合服" "${DST_DB_IP}"|iconv -f utf8 -t gbk
	##判断所给参数合法性
	#local OPRNUM="$1"
	#if [ "${OPRNUM}" ] 
	#then
	#	if [[ "$[OPRNUM]" = [123] ]]
	#	then
	#		REPORTINFO "MERGE:Operation of merge $OPRNUM"
	#	else
	#		REPORTWARN "MERGE:Operation of merge err, plz check"
	#	fi
	#else
	#REPORTINFO "MERGE:Operation of merge null"
	#fi
	#local DST_DB_IP=$NEW_DBM_IP
	#REPORTINFO "MERGE:DST_DB_IP = ${DST_DB_IP}"
	#sleep 20
	###正式合服
	#REPORTINFO "MERGE:start to merge"
	#local op=`date "+%s"`
	#local letter=$(echo ${ANNEX_PATH}|awk -F: '{print $1":"}')
	###清空日志之类的
	#ssh administrator@${DST_DB_IP} "dir ${ANNEX_PATH}log && del ${ANNEX_PATH}log\*.log" 
	#[ $? -ne 0 ] && REPORTWARN "delete log err, plz check"
	#ssh administrator@${DST_DB_IP} "dir ${ANNEX_PATH}jre\bin\java.exe && dir ${ANNEX_PATH}MergeServer.jar && ${letter} && cd ${ANNEX_PATH}jre\bin && java.exe -jar -Xmx1400m ${ANNEX_PATH}MergeServer.jar -console ${OPRNUM}" 
	#[ $? -ne 0 ] && REPORTWARN "MERGE:merge err, plz check"
	#wait
	#local ed=`date "+%s"`
	#local time_min=`expr $[${ed} - ${op}] / 60`
	#REPORTINFO "MERGE:[TIME_ALL] USE TIME_ALL ${time_min} minutes"
	echo "如果合服完毕，请输入y确认已进行合服后的检查。"|iconv -f utf8 -t gbk
	read A
	case ${A} in
	y|Y)
		REPORTINFO "wait 5 second,if you change you mind please press ctrl+c "
		sleep 8
		REPORTINFO "1 2 3 GO GO GO,Good luck"
		;;
	*)
		REPORTWARN "now we exit the shell script!"
		;;
	esac
}
#是否在线检查
function ONLINE_CHECK
{
#游戏程序检查
#用法 ONLINE_CHECK [run|stop] ip1 ip2 ip3...
local type=$1
REPORTINFO "ONLINE_CHECK:start to check server $type"
echo $type |grep -iqwE 'run|stop' || REPORTWARN "ONLINE_CHECK:option err"
shift
local CMD="$*" 
for i in ${CMD}
do
	case $type in
		stop)
			local status_num=$(ssh $i "echo \$[ \$(netstat -antp|grep -w java|grep -wc 1433) + \$(/data/jdk/bin/jps |grep -Ewic \"resin|chatserver|watchdogManager\") ]")
			[ $status_num -ne 0 ] && REPORTWARN "ONLINE_CHECK:$i GAME process is running...check it!!!"
		;;
		run)
			local status_num=$(ssh $i "echo \$(/data/jdk/bin/jps |grep -Ewic \"resin|chatserver|watchdogManager\")")
			[ $status_num -lt 3 ] && REPORTWARN "ONLINE_CHECK:$i num. of GAME process err"
		;;
		*)
			REPORTWARN "ONLINE_CHECK:option err"
		;;
	esac
done
REPORTINFO "ONLINE_CHECK:check server $type done"
}
#web服务器安装
function INSTALL_WEB_SERVER
{
	REPORTINFO "INSTALL_WEB_SERVER:funcition INSTALL_WEB_SERVER start"
	local lighttp_path="/usr/local/lighttpd/etc/lighttpd.conf"
	local libevent="/etc/ld.so.conf.d/libevent.conf"
	local web_app="/data/resin/webapps/ROOT/"
	#配置文件相关变量
	local lig_RESPONSE=$(echo $NEW_DOMAIN|awk -F. '{print $1"-"$2"-lig"}')
	case $(echo $NEW_DOMAIN|awk -F. '{print $(NF-1)}') in
		mop)
			local lig_ACCESS="10"
			local lig_errorfile="0"
			if [ $(echo $NEW_DOMAIN|cut -c 1-2) = "bd" ]
			then
				local regionid="3"
			else
				local regionid="1"
			fi
		;;
		renren)
			local lig_ACCESS="20"
			local lig_errorfile="1"
			local regionid="2"
		;;
		imop)
			local lig_ACCESS="10"
			local lig_errorfile="0"
			local regionid="4"
		;;
		hithere)
			local lig_ACCESS="10"
			local lig_errorfile="0"
			local regionid="5"
		;;
		*)
			REPORTWARN "INSTALL_WEB_SERVER:DOMAIN type err"
		;;
	esac
	#serverConsConf.xml 相关变量
	local serverid=$(ssh $SOURCE1_WEB "awk -F'\"' '/serverid/{print \$4}' /data/applib/serverConsConf.xml")
	local xb_title=$(ssh $SOURCE1_WEB "awk -F'\"' '/xb_title/{print \$4}' /data/applib/serverConsConf.xml")
	local servername=$(ssh $SOURCE1_WEB "awk -F'\"' '/servername/{print \$4}' /data/applib/serverConsConf.xml")
	CHECK_VARIABLES lighttp_path libevent web_app lig_ACCESS lig_errorfile regionid serverid xb_title servername
	REPORTINFO "INSTALL_WEB_SERVER:clean the $DATA_PATH"
	cd ${DATA_PATH:-123456} && \
	ls | egrep -v "scribe"  | xargs rm -rf
	mkdir -p ${REPOS_PATH}
	
	#拿基础软件包
	[ "$BACKUP_IP" ] || REPORTWARN "INSTALL_SERVER:backup_ip is null"
	scp $BACKUP_IP:${INSTALL_PACKAGE_PATH}WEB/${INSTALL_PACKAGE} $REPOS_PATH 
	[ $? -ne 0 ] && REPORTWARN "INSTALL_SERVER:get source package err"
	scp $BACKUP_IP:${INSTALL_PACKAGE_PATH}WEB/${INSTALL_PACKAGE_MD5} $REPOS_PATH
	[ $? -ne 0 ] && REPORTWARN "INSTALL_SERVER:get source md5file err"
	local local_md5=$(md5sum ${REPOS_PATH}${INSTALL_PACKAGE}|awk '{print $1}')
	local md5=$(cat ${REPOS_PATH}${INSTALL_PACKAGE_MD5}|awk '{print $1}')
	if [ "$local_md5" = "$md5" ]
	then
		rm -f ${REPOS_PATH}${INSTALL_PACKAGE_MD5}
	else
		REPORTWARN "INSTALL_SERVER:local source package md5 err"
	fi
	cd ${REPOS_PATH} && tar zxf ${INSTALL_PACKAGE}
	[ $? -ne 0 ] && REPORTWARN "INSTALL_SERVER: source package extract fail"
	
	#安装lighttp
	REPORTINFO "INSTALL_WEB_SERVER:start to install lighttp"
	rm -rf  /usr/local/lighttpd
	cd ${REPOS_PATH} || REPORTWARN "INSTALL_SERVER:change Directory ${REPOS_PATH} err"
	tar zxf lighttpd.tgz -C /usr/local/ || REPORTWARN "INSTALL_SERVER:lighttp extract fail"
	sed -i -e 's#ACCESS#'"$lig_ACCESS"'#g' \
	-e 's#RESPONSE#'"$lig_RESPONSE"'#g' \
	-e 's#DOMAIN#'"$NEW_DOMAIN"'#g' $lighttp_path
	[ "$lig_errorfile" -eq 1 ] && {
	sed -i '/errorfile/d' $lighttp_path || REPORTWARN "INSTALL_SERVER:modify lighttp config err"
	}
	REPORTINFO "INSTALL_WEB_SERVER:install lighttp done"
	#安装memcached
	REPORTINFO "INSTALL_WEB_SERVER:start to install memcached"
	rm -rf /usr/local/libevent /usr/local/bin/memcached ${libevent}
	cd ${REPOS_PATH} || REPORTWARN "INSTALL_SERVER:change Directory ${REPOS_PATH} err"
	tar zxf memcached.tgz || REPORTWARN "INSTALL_SERVER:memcached extract fail"
	cp -r memcached/libevent /usr/local/ || \
	REPORTWARN "INSTALL_SERVER:cp memcached/libevent to /usr/local/ err"
	cp memcached/memcached /usr/local/bin/ || \
	REPORTWARN "INSTALL_SERVER:cp memcached/memcached to /usr/local/bin/ err"
	echo "/usr/local/libevent/lib/" >> $libevent || \
	REPORTWARN "INSTALL_SERVER:modify libevent.conf err"
	/sbin/ldconfig || REPORTWARN "INSTALL_SERVER:ldconfig err"
	REPORTINFO "INSTALL_WEB_SERVER:install memcached done"
	#安装jdk&resin	
	REPORTINFO "INSTALL_WEB_SERVER:start to install jdk&resin"
	cd ${REPOS_PATH} || REPORTWARN "INSTALL_SERVER:change Directory ${REPOS_PATH} err"
	tar zxf data.tgz -C $DATA_PATH || REPORTWARN "INSTALL_SERVER:data. extract fail"
	sed -i 's#DB_IP#'"$NEW_DBM_IP"'#g' ${DATA_PATH}resin/conf/resin.conf || \
	REPORTWARN "INSTALL_SERVER:modify resin.conf err"
	REPORTINFO "INSTALL_WEB_SERVER:install jdk&resin done"
	#安装web应用
	REPORTINFO "INSTALL_WEB_SERVER:start to install web source"
	rm -f /usr/lib/libimop.so 
	rsync -aq -e 'ssh' $GAME_RESOURCE_IP:${web_app} ${web_app} || \
	REPORTWARN "INSTALL_SERVER:scp web app err"
	rsync -aq -e 'ssh' $GAME_RESOURCE_IP:${DATA_PATH}applib/ ${DATA_PATH}applib/ || \
	REPORTWARN "INSTALL_SERVER:scp applib err"
	sed -i -e '/regionid/s#\(value=\).*\( desc\)#\1'\"''"$regionid"''\"'\2#g' \
	-e '/servername/s#\(value=\).*\( desc\)#\1'\"''"$servername"''\"'\2#g' \
	-e '/serverid/s#\(value=\).*\( desc\)#\1'\"''"$serverid"''\"'\2#g' \
	-e '/domain/s#\(value=\).*\( desc\)#\1'\"''"$NEW_DOMAIN"''\"'\2#g' \
	-e '/xb_title/s#\(value=\).*\( desc\)#\1'\"''"$xb_title"''\"'\2#g' \
	-e '/DBIP/s#\(value=\).*\( desc\)#\1'\"''"$NEW_DBM_IP"''\"'\2#g' \
	-e '/languageType/s#\(value=\).*\( desc\)#\1'\"''"$LANG_VERSION"''\"'\2#g' \
	${DATA_PATH}applib/serverConsConf.xml || REPORTWARN "INSTALL_SERVER:modify serverConsConf.xml err"
	scp $GAME_RESOURCE_IP:/usr/lib/libimop.so /usr/lib/libimop.so && \
	scp $GAME_RESOURCE_IP:${DATA_PATH}resin/lib/imop-cl.jar ${DATA_PATH}resin/lib/imop-cl.jar && \
	scp $GAME_RESOURCE_IP:${DATA_PATH}resin/lib/resin.jar ${DATA_PATH}resin/lib/resin.jar
	[ $? -ne 0 ] && REPORTWARN "INSTALL_SERVER:scp so or jar err"
	REPORTINFO "INSTALL_WEB_SERVER:install web source done"
	#安装chatserver
	REPORTINFO "INSTALL_WEB_SERVER:start to install chatserver"
	rsync -aq -e 'ssh' $GAME_RESOURCE_IP:${DATA_PATH}ChatServer/ ${DATA_PATH}ChatServer/ && \
	sed -i 's/'"$GAME_RESOURCE_IP"'/'"$NEW_WEB_IP"'/' ${DATA_PATH}ChatServer/conf/chat.properties
	[ $? -ne 0 ] && REPORTWARN "INSTALL_SERVER:chatserver install fail"
	REPORTINFO "INSTALL_WEB_SERVER:install chatserver done"
	#设置local
	REPORTINFO "INSTALL_WEB_SERVER:modify hosts for local"
	sed -i '/^[1-9].*local.sg.mop.com/d' /etc/hosts && \
	ssh $GAME_RESOURCE_IP "grep \"local.sg.mop.com\" /etc/hosts" >> /etc/hosts
	[ $? -ne 0 ] && REPORTWARN "INSTALL_WEB_SERVER:modify local err"
	REPORTINFO "INSTALL_WEB_SERVER:modify local done"
	#生成key
	REPORTINFO "INSTALL_WEB_SERVER:create the license"
	cd ${REPOS_PATH} || REPORTWARN "INSTALL_SERVER:change Directory ${REPOS_PATH} err"
	mkdir -p ${DATA_PATH}license && cp keygen2_x64_RHEL4 ${DATA_PATH}license 
	cd ${DATA_PATH}license && chmod 755 keygen2_x64_RHEL4 && ./keygen2_x64_RHEL4 && cp imop.key ${NEW_WEB_IP}.key && \
	ftp -inv <<!EOF
		open ${FTP_IP} 21
		user ${FTP_USER} ${FTP_PASS}
		cd ${FTP_LICENSE_PATH}
		mkdir ${NEW_DOMAIN}
		cd ${NEW_DOMAIN}
		prompt
		put ${NEW_WEB_IP}.key
		bye
!EOF
[ $? -ne 0 ] && REPORTWARN "INSTALL_SERVER:create license err"
REPORTINFO "INSTALL_WEB_SERVER:create the license done"
}
#db服务器安装准备
function INSTALL_DB_SERVER
{
#因为是windows，所以只能准备好东西，去windows上装
	REPORTINFO "INSTALL_DB_SERVER:Preparing for Installation db, plz wait"
	local filter
	local DOMAIN=$(echo ${NEW_DOMAIN} |awk -F. '{print $(NF-1)"."$NF}')
	while :
	do
		if ! [ "$filter" ]
		then
			local dir=$(ssh ${BACKUP_IP} "find /data/SG -type d -name \"*${DOMAIN}*\" |xargs du -h|grep -w '^[0-9]*G' |sort -n|awk 'NR==1{print \$NF}'")
		else
			local dir=$(ssh ${BACKUP_IP} "find /data/SG -type d -name \"*${DOMAIN}*\" |xargs du -h|grep -w '^[0-9]*G' |sort -n|grep -Ewv '$(echo ${filter}|sed -e 's#^|##' -e 's#|$##')'|awk 'NR==1{print \$NF}'")
		fi
		local file=$(ssh ${BACKUP_IP} "ls -lth $dir|awk 'NR==2{print \$NF}'")
		if [ "${file%.*}" = $(date +%y-%m-%d) ] 
		then
			break 
		else
			filter="$(echo $dir|xargs basename)|${filter}"
		fi
	done
	[ "$dir" ] || REPORTWARN "INSTALL_DB_SERVER:get backup_file err"
	local backup_name=$(ssh ${BACKUP_IP} "rar vb $dir/$file")
	ssh ${BACKUP_IP} "
		md5sum ${INSTALL_PACKAGE_PATH}DB/SG_DB_SERVER_INSTALL.tgz |awk '{print \$1}' |grep -qw \$(cat ${INSTALL_PACKAGE_PATH}DB/SG_DB_SERVER_INSTALL_MD5 |awk '{print \$1}') || exit 1
		rm -rf ${INSTALL_PACKAGE_PATH}DB/${NEW_WEB_IP}/
		mkdir -p ${INSTALL_PACKAGE_PATH}DB/${NEW_WEB_IP}/
		rm -rf ${INSTALL_PACKAGE_PATH}DB/${NEW_WEB_IP}/*
		tar zxf ${INSTALL_PACKAGE_PATH}DB/SG_DB_SERVER_INSTALL.tgz -C ${INSTALL_PACKAGE_PATH}DB/${NEW_WEB_IP}/ || exit 1
		mkdir -p ${INSTALL_PACKAGE_PATH}DB/${NEW_WEB_IP}/software/restore
		rm -rf ${INSTALL_PACKAGE_PATH}DB/${NEW_WEB_IP}/software/restore/*
		cp $dir/$file ${INSTALL_PACKAGE_PATH}DB/${NEW_WEB_IP}/software/restore/ || exit 1
		cd ${INSTALL_PACKAGE_PATH}DB/${NEW_WEB_IP}/software/sg_install_db
		dos2unix install.txt >/dev/null 2>&1
		sed -i -e '/servicename/s#\$#${NEW_DOMAIN%%.*}#g' -e '/backuppath/s#\$#D:\\\\software\\\\restore\\\\$(echo ${backup_name}|sed 's#/#\\\\#g')#g' install.txt || exit 1
		unix2dos install.txt >/dev/null 2>&1
		chown -R backup.backup ${INSTALL_PACKAGE_PATH}DB/${NEW_WEB_IP}/software/
	"
	[ $? -ne 0 ] && REPORTWARN "INSTALL_DB_SERVER:modify db_config err"
	echo -n "请在windows上先解压"|iconv -f utf8 -t gbk
	echo -n "d:\software\restore\\$backup_name"
	echo "，选择解压到当前目录即可，再执行安装脚本"|iconv -f utf8 -t gbk
	REPORTINFO "INSTALL_DB_SERVER:the Preparation of install db done, plz install on windows"
}
#合服检查
function MERGE_CHECK
{
	REPORTINFO "MERGE_CHECK:function MERGE_CHECK start"
	#拿取合服日志
	rm -rf ${REPOS_PATH}logtmp
	mkdir -p ${REPOS_PATH}logtmp
	scp administrator@$NEW_DBM_IP:d:/\merge_tools/\log/\* ${REPOS_PATH}logtmp
	[ $? -ne 0 ] && REPORTWARN "MERGE_CHECK:get merge log err"
	cd ${REPOS_PATH}logtmp && dos2unix * >/dev/null 2>&1
	[ -s ${REPOS_PATH}logtmp/error.log ] && REPORTWARN "MERGE_CHECK:something in errlog, merge fail"
	[ -s ${REPOS_PATH}logtmp/info.log ] || REPORTWARN "MERGE_CHECK:info_log is empty or not exist, merge fail"
	grep -qw "SystemConfig([0-9][0-9]*/[0-9][0-9]*).*Brole([0-9][0-9]*/[0-9][0-9]*)" ${REPOS_PATH}logtmp/info.log
	[ $? -ne 0 ] && REPORTWARN "MERGE_CHECK:the sign of merge err, merge fail"
	REPORTINFO "MERGE_CHECK:function MERGE_CHECK done"
}
#检查source
function CHECKIP_SOURCE
{
	[ $# -eq 2 ] || REPORTWARN "CHECK_SOURCE:option err"
	local ip=$1
	local domain=$2
	local oip=$(ssh $ip "/sbin/ip a|grep inet|grep -v ":"|grep -Ev '192\.|172\.|10.|127\.'|awk '{print \$2}'|xargs -i dirname {}")
	local doip=$(/usr/bin/dig $domain|grep -w '^'"$domain"'' |grep -w 'A' |awk '{print $NF}')
	[ "${oip}" ] && [ "$doip" ]
	[ $? -ne 0 ] && REPORTWARN "CHECK_SOURCE:source $domain ip err"
	[ $oip != $doip ] && REPORTWARN "CHECK_SOURCE:source $domain ip err"
	echo -e "\033[31;1m$domain webip = $ip & $doip\033[0m"
}
#对源服信息的MERGE进行数据全备
function DUMP_MERGE_ALL
{
	#用法DUMP_MERGE_ALL [wardb3|wardb3log] ip1 ip2 ip3 ... ,函数里会根据ALL_SOURCE_DB_IP 检查ip合法性，防止手动输入时出现问题
	REPORTINFO "IDUMP_MERGE_ALL:FUNCTION IDUMP_MERGE_ALL START"
	>${LOG_PATH}log.tmp
	local dbname=$1
	eval local BACKUP_WIN="d:\\\\${dbname}backup_local\\\\"
	[ $# -le `expr ${SOURCE_NUM} + 1` ] ||  REPORTWARN "DUMP_MERGE_ALL:operation err,plz check"
	[ "${dbname}" ] || REPORTWARN "DUMP_MERGE_ALL:backup db name is null, plz check"
	echo  ${dbname} | grep -iEwq "wardb3|wardb3log" || REPORTWARN "DUMP_MERGE_ALL:backup db name err, plz check"
	shift 
	for i in $*
	do
		echo ${ALL_SOURCE_DB_IP} | grep -wq $i || REPORTWARN "DUMP_MERGE_ALL:SOURCE_IP $i err, plz check"
	done
	sleep 20
	for i in $*
	do
			ssh administrator@$i "dir ${BACKUP_WIN}WIN_DB_${dbname}_${DAY}.bak " >/dev/null 2>&1
			if [ $? -ne 0 ] 
			then
				{
				ssh administrator@$i "dir ${BACKUP_WIN} > nul || mkdir ${BACKUP_WIN}" >/dev/null 2>&1 
				ssh administrator@$i "del ${BACKUP_WIN}* /Q/F" 
				ssh administrator@$i "sqlcmd -S localhost -U ${GAMEDB_USER} -P ${M_PW} -Q \"backup database ${dbname} to disk='${BACKUP_WIN}WIN_DB_${dbname}_${DAY}.bak'\" " | \
				iconv -f GBK -t UTF-8 | \
				grep -q 'BACKUP DATABASE 成功处理' || \
					{
					REPORTINFO "DUMP_MERGE_ALL:$i sqlserver dump err, plz check" &&  echo "$i err" >> ${LOG_PATH}log.tmp
					} 
				ssh administrator@$i "dir ${BACKUP_WIN}WIN_DB_${dbname}_${DAY}.bak " >/dev/null 2>&1
				[ $? -ne 0 ] && \
					{
					REPORTINFO "DUMP_MERGE_ALL:$i sqlserver dump err, plz check" &&  echo "$i err" >> ${LOG_PATH}log.tmp
					} 
				} &	
			else 
				REPORTINFO "DUMP_MERGE_ALL:$i is already backup"
			fi
		sleep 2
	done
	wait
	grep -iq err ${LOG_PATH}log.tmp && {
	rm -f ${LOG_PATH}log.tmp
	REPORTWARN "DUMP_MERGE_ALL:sqlserver dump err, plz check"
	}
	REPORTINFO "DUMP_MERGE_ALL:FUNCTION IDUMP_MERGE_ALL DONE"
}
#拿取license，用法GET_LICENSE 需要拿取的IP1 IP2 IP3 ......
function GET_LICENSE
{
[[ $# -ge 1 ]] || REPORTWARN "function use error,please read the function explain"
local I="$*"
for ip in ${I}
do
	REPORTINFO "now we download the license"
	ssh ${ip} "mkdir -p ${LICENSE_PATH} && wget --user=${FTP_USER} --password=${FTP_PASS} ftp://${FTP_IP}${FTP_LICENSE_PATH}/${NEW_DOMAIN}/${ip}.lic -P ${LICENSE_PATH}"
	ssh ${ip} "scp -rp ${LICENSE_PATH}${ip}.lic ${LICENSE_PATH}imop.lic && scp -rp ${LICENSE_PATH}${ip}.lic /root/"
	ssh ${ip} "[[ -s ${LICENSE_PATH}imop.lic ]]" || REPORTWARN "${ip} download license fail,maybe the licese not create or key not upload"
done
}

#合服类型选择提示
echo -e "PLEASE INPUT THE MERGE TYPE,if TEST INPUT 0 ELSE INPUT 1"
read TYPE
#获取合服信息
GET_MERGE_INFO
#初始化本机vim环境
INIT_VIMRC
#list合法性完整性检查，变量相关检查
CHECK_LIST
#输出&问
ECHO_AND_ASK

case $TYPE in
	0)
		MERGE_TYPE_CHECK 0
		echo "TEST MERGE IS AS FOLLOWS"
		echo -e "\033[31;1ma.ready to merge, stop & start server, data import, ready for merge_tools\033[0m"
		echo -e "\033[31;1mb.init merge db & merge\033[0m"
		echo -e "\033[31;1mc.run them all\033[0m"
		echo -e "\033[31;1md.merge check\033[0m"
		echo "plz input the STEP of you choose"
		read STEP
		case $STEP in
			a|A)
				##停止包括merge在内的6组合服机
				REPORTINFO "start to stop source web"
				for i in ${ALL_SOURCE_WEB_IP} ${NEW_WEB_IP}
				do
					ssh $i "sh /root/shell/sg_stop.sh"  
					wait
				done
				REPORTINFO "stop server over"
				sleep 10
				ONLINE_CHECK stop ${ALL_SOURCE_WEB_IP} ${NEW_WEB_IP}
				#合服测试灌库
				REPORTINFO "start to import data"
				>${LOG_PATH}log.tmp
				for i in `seq 1 $SOURCE_NUM`
				do
				DATA_IMPORT $i &
				sleep 1
				done
				wait
				grep "err" ${LOG_PATH}log.tmp && REPORTWARN "DATA_IMPORT:err"
				rm -f ${LOG_PATH}log.tmp
				REPORTINFO "import data done"
				#启动除merge目标机外的source机web
				REPORTINFO "start to run source web"
				for i in ${ALL_SOURCE_WEB_IP}
				do
					ssh $i "sh /root/shell/sg_start.sh "  
					wait
				done
				sleep 10
				ONLINE_CHECK run ${ALL_SOURCE_WEB_IP}
				#修改合服用配置文件并上传至merge目标db上
				REPORTINFO "start to MODIFY_AND_UPDATE"
				MODIFY_AND_UPDATE
			;;
			b|B)
				REPORTINFO "start to INIT MERGE DB"
				#初始化merge目标db
				INIT_DB
				#测试合服
				MERGE
				#合服检查
				MERGE_CHECK
				#起程序
				REPORTINFO "start to run merge web"
				ssh ${NEW_WEB_IP} "sh /root/shell/sg_start.sh"
				sleep 10
				ONLINE_CHECK run ${NEW_WEB_IP}
				#设置local
				REPORTINFO "INSTALL_WEB_SERVER:modify hosts for local"
				sed -i '/^[1-9].*local.sg.mop.com/d' /etc/hosts && \
				ssh $GAME_RESOURCE_IP "grep \"local.sg.mop.com\" /etc/hosts" >> /etc/hosts
				[ $? -ne 0 ] && REPORTWARN "INSTALL_WEB_SERVER:modify local err"
				REPORTINFO "INSTALL_WEB_SERVER:modify local done"
				#打包合服日志并下载到本机
				REPORTINFO "start to tar merge log and download it"
				REPORTINFO "logpath=$${LOG_PATH}${NEW_DOMAIN%%.*}-merge-log.tgz"
				tar zcf ${LOG_PATH}${NEW_DOMAIN%%.*}-$(date +%y%m%d)-merge-log.tgz ${REPOS_PATH}logtmp/* && \
				sz ${LOG_PATH}${NEW_DOMAIN%%.*}-$(date +%y%m%d)-merge-log.tgz
				[ $? -ne 0 ] && REPORTWARN "download the log err"
				echo "合服日志已下载完毕，合服结束"|iconv -f utf8 -t gbk
			;;
			c|C)
				##停止包括merge在内的6组合服机
				REPORTINFO "start to stop source web"
				for i in ${ALL_SOURCE_WEB_IP} ${NEW_WEB_IP}
				do
					ssh $i "sh /root/shell/sg_stop.sh"  
					wait
				done
				REPORTINFO "stop server over"
				sleep 10
				ONLINE_CHECK stop ${ALL_SOURCE_WEB_IP} ${NEW_WEB_IP}
				#合服测试灌库
				REPORTINFO "start to import data"
				for i in `seq 1 $SOURCE_NUM`
				do
				DATA_IMPORT $i &
				sleep 1
				done
				wait
				grep "err" ${LOG_PATH}log.tmp && REPORTWARN "DATA_IMPORT:err"
				rm -f ${LOG_PATH}log.tmp
				REPORTINFO "import data done"
				#启动除merge目标机外的source机web
				REPORTINFO "start to run source web"
				for i in ${ALL_SOURCE_WEB_IP}
				do
					ssh $i "sh /root/shell/sg_start.sh "  
					wait
				done
				sleep 10
				ONLINE_CHECK run ${ALL_SOURCE_WEB_IP}
				#修改合服用配置文件并上传至merge目标db上
				REPORTINFO "start to MODIFY_AND_UPDATE"
				MODIFY_AND_UPDATE
				REPORTINFO "start to INIT MERGE DB"
				#初始化merge目标db
				INIT_DB
				#测试合服
				MERGE
			;;
			d|D)
				#合服检查
				MERGE_CHECK
				#起程序
				REPORTINFO "start to run merge web"
				ssh ${NEW_WEB_IP} "sh /root/shell/sg_start.sh"
				sleep 10
				ONLINE_CHECK run ${NEW_WEB_IP}
				#设置local
				REPORTINFO "INSTALL_WEB_SERVER:modify hosts for local"
				sed -i '/^[1-9].*local.sg.mop.com/d' /etc/hosts && \
				ssh $GAME_RESOURCE_IP "grep \"local.sg.mop.com\" /etc/hosts" >> /etc/hosts
				[ $? -ne 0 ] && REPORTWARN "INSTALL_WEB_SERVER:modify local err"
				REPORTINFO "INSTALL_WEB_SERVER:modify local done"
				#打包合服日志并下载到本机
				REPORTINFO "start to tar merge log and download it"
				REPORTINFO "logpath=$${LOG_PATH}${NEW_DOMAIN%%.*}-merge-log.tgz"
				tar zcf ${LOG_PATH}${NEW_DOMAIN%%.*}-$(date +%y%m%d)-merge-log.tgz ${REPOS_PATH}logtmp/* && \
				sz ${LOG_PATH}${NEW_DOMAIN%%.*}-$(date +%y%m%d)-merge-log.tgz
				[ $? -ne 0 ] && REPORTWARN "download the log err"
				echo "合服日志已下载完毕，合服结束"|iconv -f utf8 -t gbk
			;;
			*)
				REPORTWARN "input error,check it"
			;;
		esac
	;;
	1)
		MERGE_TYPE_CHECK 1
		echo "TEST MERGE IS AS FOLLOWS"
		echo -e "\033[31;1ma.BEFORE MERGE, YOU WANT TO INSTALL A SERVER LIKE SOMEONE ONLINE\033[0m"
		echo -e "\033[31;1mb.CHECK SOURCEIP, STOP IT, BACKUP IT AND UPDATE THE MERGE CONFIG\033[0m"
		echo -e "\033[31;1mc.INIT MERGEDB AND START TO MERGE\033[0m"
		echo -e "\033[31;1md.GET_LICENSE\033[0m"
		echo -e "\033[31;1me.MERGE FAIL, RESTORE THE SOURCEDB\033[0m"
		echo -e "\033[31;1mf.MERGE Complete, START TO BACKUP LOG DATABAES\033[0m"
		echo -e "\033[31;1mg.MERGE Complete, merge check\033[0m"
		echo "plz input the STEP of you choose"
		read STEP
		case $STEP in
			a|A)
				#检查新服进程
				ONLINE_CHECK stop ${NEW_WEB_IP}
				#装新服-web
				INSTALL_WEB_SERVER
				#装新服-准备db
				INSTALL_DB_SERVER
				#不知道有没有添加gm后台的步骤
				
				
				
			;;
			b|B)
				#检查源服ip
				for i in `seq 1 $SOURCE_NUM`
				do
				eval CHECKIP_SOURCE '$'SOURCE${i}_WEB '$'SOURCE${i}_DOMAIN
				done
				ASK_AND_CONFIRM
				#停sourceweb
				for i in ${ALL_SOURCE_WEB_IP} ${NEW_WEB_IP}
				do
					ssh $i "sh /root/shell/sg_stop.sh"  
					wait
				done			
				sleep 10
				ONLINE_CHECK stop ${ALL_SOURCE_WEB_IP} ${NEW_WEB_IP}
				#备份所有sourcedb到其本地
				DUMP_MERGE_ALL wardb3 ${ALL_SOURCE_DB_IP}
				#起web
				for i in ${ALL_SOURCE_WEB_IP}
				do
					ssh $i "sh /root/shell/sg_start.sh "  
					wait
				done
				sleep 10
				ONLINE_CHECK run ${ALL_SOURCE_WEB_IP}			
				REPORTINFO "start to MODIFY_AND_UPDATE"
				MODIFY_AND_UPDATE
			;;
			c|C)
				#检查sourceip
				for i in `seq 1 $SOURCE_NUM`
				do
				eval CHECKIP_SOURCE '$'SOURCE${i}_WEB '$'SOURCE${i}_DOMAIN
				done
				ASK_AND_CONFIRM
				ONLINE_CHECK run ${ALL_SOURCE_WEB_IP}
				ONLINE_CHECK stop ${NEW_WEB_IP}
				REPORTINFO "start to INIT MERGE DB"
				#初始化merge目标db
				INIT_DB
				#测试合服
				MERGE
			;;
			g|G)
				#合服检查
				MERGE_CHECK
				#起程序
				REPORTINFO "start to run merge web"
				ssh ${NEW_WEB_IP} "sh /root/shell/sg_start.sh"
				sleep 10
				ONLINE_CHECK run ${NEW_WEB_IP}
				#备份log库，是哪个log库还是所有的服务器的log库
				
				
				#打包合服日志并下载到本机
				REPORTINFO "start to tar merge log and download it"
				REPORTINFO "logpath=$${LOG_PATH}${NEW_DOMAIN%%.*}-merge-log.tgz"
				tar zcf ${LOG_PATH}${NEW_DOMAIN%%.*}-$(date +%y%m%d)-merge-log.tgz ${REPOS_PATH}logtmp/* && \
				sz ${LOG_PATH}${NEW_DOMAIN%%.*}-$(date +%y%m%d)-merge-log.tgz
				[ $? -ne 0 ] && REPORTWARN "download the log err"
				echo "合服日志已下载完毕，合服结束"|iconv -f utf8 -t gbk
			;;
			d|D)
				#GET_LICENSE
				GET_LICENSE ${NEW_WEB_IP}
			;;
			e|E)
			#生成restoresql并上传至db
			REPORTINFO "create restoresql, scp to sourcedb & restore sourcedb"
			mkdir -p /data/merge/restoresql_tmp/
			rsync -aq -e 'ssh' ${BACKUP_IP}:${MERGE_TOOLS_PATH}restore/ /data/merge/restoresql_tmp/
			dos2unix /data/merge/restoresql_tmp/* >/dev/null 2>&1
			for i in `seq 1 $SOURCE_NUM`
			do
				eval x='$'SOURCE${i}_DOMAIN
				x=${x%%.*}
				cp /data/merge/restoresql_tmp/restore.sql  /data/merge/restoresql_tmp/SOURCE${i}_DB.sql && \
				sed -i -e '/DISK/s#D:.*'\''#D:\\wardb3backup_local\\WIN_DB_wardb3_'"${DAY}"'.bak'\''#g' \
				-e 's#merge_db#'"${x}"'_db#g' /data/merge/restoresql_tmp/SOURCE${i}_DB.sql 
				[ $? -ne 0 ] && REPORTWARN "modify restoresql err"
			done
			unix2dos /data/merge/restoresql_tmp/* >/dev/null 2>&1
			>${LOG_PATH}log.tmp
			for i in `seq 1 $SOURCE_NUM`
			do
				eval scp /data/merge/restoresql_tmp/SOURCE${i}_DB.sql administrator@'$'{SOURCE${i}_DB}:d:// && \
				{
				eval REPORTINFO "start to restore '$'SOURCE${i}_DOMAIN "
				eval ssh administrator@'$'{SOURCE${i}_DB} "sqlcmd -i \"d:\SOURCE"${i}"_DB.sql\" -S localhost -U ${GAMEDB_USER} -P ${M_PW}"| \
				iconv -f GBK -t UTF-8 | \
				grep -q 'RESTORE DATABASE 成功处理' || \
				echo 'SOURCE${i}_DB RESTORE err' >> ${LOG_PATH}log.tmp 
				} &
				sleep 2
			done
			wait
			grep "err" ${LOG_PATH}log.tmp && REPORTWARN "RESTORE err, plz check ${LOG_PATH}log.tmp"
			rm -rf ${LOG_PATH}log.tmp
			REPORTINFO "restore sourcedb done"
			;;
			f|F)
				#检查源服ip
				for i in `seq 1 $SOURCE_NUM`
				do
				eval CHECKIP_SOURCE '$'SOURCE${i}_WEB '$'SOURCE${i}_DOMAIN
				done
				ASK_AND_CONFIRM
				#停sourceweb
				for i in ${ALL_SOURCE_WEB_IP} 
				do
					ssh $i "sh /root/shell/sg_stop.sh"  
					wait
				done			
				sleep 10
				ONLINE_CHECK stop ${ALL_SOURCE_WEB_IP} 
				#备份所有sourcedb到其本地
				DUMP_MERGE_ALL wardb3log ${ALL_SOURCE_DB_IP}
				echo "log库备份完毕，现存放在sourcedb的d:\wardb3log" |iconv -f utf8 -t gbk
			;;
			*)
				REPORTWARN "input error,check it"
			;;
		esac
	;;
	*)
		:
	;;
esac




#!/bin/bash

# 安装xtrabackup
function install_xtrabackup()
{
	show_log "Install xtrabackup ..."
 
	cd $DIST_DIR
	if [ ! -f "$XTRABACKUP.tar.gz" ]; then
		show_log "Download $XTRABACKUP ..."
		local percona=$XTRABACKUP
		local bit=`getconf LONG_BIT`
		if [ "$bit" == 32 ]; then
			percona="${percona}_i686"
		else
			percona="${percona}_x86_64"
		fi

		download $DIST_URL/../bin/$percona.tar.gz
	fi

	cd src/
	local xtrabackup_dir=`echo $XTRABACKUP |sed 's/-[0-9]\+$//'`
	if [ ! -d "$xtrabackup_dir" ]; then
		show_log "tar zxf ../$percona.tar.gz"
		tar zxf ../$percona.tar.gz
	fi

	mkdir -p /data/opt/mysql-backup/
	cp $xtrabackup_dir/bin/* /data/opt/mysql-backup/
	chmod a+x /data/opt/mysql-backup/*
	sed -i "/mysql-backup/d" /data/bin/profile.sh
	echo "export PATH=/data/opt/mysql-backup:\$PATH" >> /data/bin/profile.sh

	show_log "Xtrabackup installed!"
}

# 安装mysqlhotcopy
function install_mysqlhotcopy()
{
	show_log "Install mysqlhotcopy ..."
	local install_log=$LOGS_DIR/$XTRABACKUP.log

	# Perl module
	yum install perl-DBI perl-DBD-MySQL -y --nogpgcheck >> $install_log 2>&1
	mkdir -p /data/opt/mysql-backup/
	
	# Mysql original hotcopy
	local mysqlhotcopy=/data/opt/mysql/bin/mysqlhotcopy
	if [ ! -f $mysqlhotcopy ]; then
		show_log "Error: mysqlhotcopy not found!"
		return 0
	fi

	# Custom mysqlhotcopy
	cp $mysqlhotcopy /data/opt/mysql-backup/
	mysqlhotcopy=/data/opt/mysql-backup/mysqlhotcopy
	sed -i "/\\.ibd\\\'/d" $mysqlhotcopy
	line=$(grep -n 'foreach ' $mysqlhotcopy  |grep \@sources| tail -n 1 | awk -F ':' '{print $1}')
	sed -i "${line}a\	next if \$_ =~ /\\\.ibd\\\'$/i;" $mysqlhotcopy
	chmod a+x /data/opt/mysql-backup/mysqlhotcopy

	show_log "Mysqlhotcopy installed!"
}

# 安装备份脚本
function install_mysql_backup
{
	install_xtrabackup
	install_mysqlhotcopy
	cp -f $CONF_DIR/xtrabackup/mysql-backup.sh /data/bin/
	chmod a+x /data/bin/mysql-backup.sh
}


#!/bin/bash
## Filename:mysql_ps1.sh

ls /data/mysql/ > /dev/null 2>&1

if [[ $? -eq 0 ]];
then
	sed -i "/MYSQL_PS1/d" /etc/profile
        echo export MYSQL_PS1=\"\\u@`ls /data/mysql/|grep -v mysql.3306.pid`" (\d) > "\"  >>/etc/profile
        source /etc/profile >/dev/null 2>&1
        echo "`ls /data/mysql/` is ok." 
fi


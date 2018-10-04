#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

DATA_DIR=/data/mariadb

echo -e "\033[32m1:安装MariaDB\033[0m"
echo -e "\033[32m2:配置MariaDB_Galera_Cluster\033[0m"
read -p "输入选项进行安装:" action
#检测变量输入是否为空
if [ -z "${action}" ]; then
        echo -e "\033[31m"请从新运行$0此脚本，并输入选项进行安装."\033[0m"
        exit
fi

if [ "${action}" -eq "1" ]; then
	echo -ne "\033[33m请输入数据库管理员密码:\033[0m"
	read db_root_password
	
	yum install MariaDB-server MariaDB-client galera  -y
	
	mkdir -p ${DATA_DIR}
	cp -Rf /var/lib/mysql/* ${DATA_DIR}/
	chown -R mysql:mysql ${DATA_DIR}
	
	rm -rf /etc/my.cnf.d/*
	wget -c http://shell-pdns.test.upcdn.net/rpm/my.cnf -O /etc/my.cnf.d/server.cnf
		
	/usr/bin/firewall-cmd --zone=public --add-port=3306/tcp --permanent
	/usr/bin/firewall-cmd --reload
	
	systemctl enable mysql &systemctl start mysql
	#开始配置Mysql_secure_installation
	SECURE_MYSQL=$(expect -c "
	set timeout 3
	spawn /usr/bin/mysql_secure_installation
	expect \"Enter current password for root (enter for none):\"
	send \"\r\"
	expect \"Set root password?\"
	send \"y\r\"
	expect \"New password:\"
	send \"${db_root_password}\r\"
	expect \"Re-enter new password:\"
	send \"${db_root_password}\r\"
	expect \"Remove anonymous users?\"
	send \"y\r\"
	expect \"Disallow root login remotely?\"
	send \"y\r\"
	expect \"Remove test database and access to it?\"
	send \"y\r\"
	expect \"Reload privilege tables now?\"
	send \"y\r\"
	expect eof
	")
	echo "${SECURE_MYSQL}"
	echo -e "\033[31m数据库密码是:${db_root_password}\033[0m"
	sed -i "s#db_root_password=''#db_root_password='${db_root_password}'#" ./config.conf
elif [ "${action}" -eq "2" ]; then
	echo -ne "\033[31m是否设置XtraBackup授权账号\033[0m(只需在DB1上设置一次,y/n):"
	read xtrabackup_name
		if [ ${xtrabackup_name} = "y" ]; then
			read -p "输入数据库管理员密码:" db_root_password
			/usr/bin/mysql -u root -p${db_root_password} << EOF
grant all on *.* to 'galera'@'%' identified by '${db_root_password}';
flush privileges;
EOF
		else
			echo -ne "\033[33m输入XtraBackup授权账号密码(DB1数据库管理员密码):\033[0m"
			read db_root_password
		fi
	systemctl stop mysql
	read -p "输入集群名称:" cluster_name
	read -p "输入集群IP:" cluster_ip
	read -p "输入节点名称:" node_name
	read -p "输入节点IP:" node_ip
	
	yum install http://www.percona.com/downloads/percona-release/redhat/0.1-6/percona-release-0.1-6.noarch.rpm -y
	yum install percona-xtrabackup-24 -y
	
	cat >> /etc/my.cnf.d/server.cnf <<EOF
	
[galera]
wsrep_on=ON
wsrep_provider = /usr/lib64/galera/libgalera_smm.so
wsrep_provider_options = "gcache.size=8G; gcache.page_size=4G; gcs.fc_limit = 256; gcs.fc_factor = 0.8;"
wsrep_certify_nonPK=ON
wsrep_cluster_name="${cluster_name}"
wsrep_cluster_address="gcomm://${cluster_ip}"
wsrep_node_name=${node_name}
wsrep_node_address=${node_ip}
wsrep_slave_threads=4
wsrep_causal_reads = OFF
wsrep_sst_auth=galera:${db_root_password}
wsrep_sst_method=xtrabackup-v2
EOF
	sed -i "s#bind-address = 0.0.0.0#bind-address = ${node_ip}#" /etc/my.cnf.d/server.cnf
	/usr/bin/firewall-cmd --zone=public --add-port=4567/tcp --permanent
	/usr/bin/firewall-cmd --zone=public --add-port=4568/tcp --permanent
	/usr/bin/firewall-cmd --zone=public --add-port=4444/tcp --permanent
	/usr/bin/firewall-cmd --reload

	if [ $? -eq 0 ]; then
		echo -ne "\033[31m是否启动Galera_Cluster(y/n):\033[0m"
		read action2
			if [ ${action2} = "y" ]; then
				/usr/bin/galera_new_cluster
			else
				systemctl start mysql
			fi
	fi
fi

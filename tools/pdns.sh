#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

echo "1:安装Master服务器"
echo "2:安装Slave服务器"
echo "3:配置Slave服务器"

read -p "请输入选项进行安装:" action
#检测变量输入是否为空
if [ -z "${action}" ]; then
        echo -e "\033[31m"请从新运行$0此脚本，并输入选项进行安装."\033[0m"
        exit
fi

if [ ${action} -eq 1 ]; then
	read -p "输入主机名(完整的FQDN):" host_name
	read -p "输入Slave服务器IP:" slave_ip
	read -p "输入数据库管理员密码:" db_root_password
	read -p "输入需要创建的数据库用户名:" db_user
	read -p "输入需要创建的数据库用户密码:" db_user_password
	read -p "输入需要创建的数据库名:" db_name	
	read -p "请输入api_key:" api_key

	#设置主机名
	/usr/bin/hostnamectl set-hostname ${host_name}
	#安装pdns
	yum install epel-release yum-plugin-priorities mariadb -y
	curl -o /etc/yum.repos.d/powerdns-auth-master.repo https://repo.powerdns.com/repo-files/centos-auth-master.repo
	rpm --import https://repo.powerdns.com/CBC8B383-pub.asc
	yum install pdns pdns-backend-mysql -y

	#创建数据库已经pdns用户
	host=127.0.0.1
	username=root
	/usr/bin/mysql -h${host} -u ${username} -p${db_root_password} << EOF
CREATE DATABASE ${db_name};
GRANT ALL ON ${db_name}.* TO '${db_user}'@'%' IDENTIFIED BY '${db_user_password}';
FLUSH PRIVILEGES;
EOF
	#以下为创建pdns所需要用到的表
	/usr/bin/mysql -h${host} -u ${username} -p${db_root_password} -D ${db_name}<< EOF
CREATE TABLE domains (
  id                    INT AUTO_INCREMENT,
  name                  VARCHAR(255) NOT NULL,
  master                VARCHAR(128) DEFAULT NULL,
  last_check            INT DEFAULT NULL,
  type                  VARCHAR(6) NOT NULL,
  notified_serial       INT UNSIGNED DEFAULT NULL,
  account               VARCHAR(40) CHARACTER SET 'utf8' DEFAULT NULL,
  PRIMARY KEY (id)
) Engine=InnoDB CHARACTER SET 'latin1';

CREATE UNIQUE INDEX name_index ON domains(name);
CREATE TABLE records (
  id                    BIGINT AUTO_INCREMENT,
  domain_id             INT DEFAULT NULL,
  name                  VARCHAR(255) DEFAULT NULL,
  type                  VARCHAR(10) DEFAULT NULL,
  content               VARCHAR(64000) DEFAULT NULL,
  ttl                   INT DEFAULT NULL,
  prio                  INT DEFAULT NULL,
  change_date           INT DEFAULT NULL,
  disabled              TINYINT(1) DEFAULT 0,
  ordername             VARCHAR(255) BINARY DEFAULT NULL,
  auth                  TINYINT(1) DEFAULT 1,
  PRIMARY KEY (id)
) Engine=InnoDB CHARACTER SET 'latin1';

CREATE INDEX nametype_index ON records(name,type);
CREATE INDEX domain_id ON records(domain_id);
CREATE INDEX ordername ON records (ordername);
CREATE TABLE comments (
  id                    INT AUTO_INCREMENT,
  domain_id             INT NOT NULL,
  name                  VARCHAR(255) NOT NULL,
  type                  VARCHAR(10) NOT NULL,
  modified_at           INT NOT NULL,
  account               VARCHAR(40) CHARACTER SET 'utf8' DEFAULT NULL,
  comment               TEXT CHARACTER SET 'utf8' NOT NULL,
  PRIMARY KEY (id)
) Engine=InnoDB CHARACTER SET 'latin1';

CREATE INDEX comments_name_type_idx ON comments (name, type);
CREATE INDEX comments_order_idx ON comments (domain_id, modified_at);
CREATE TABLE domainmetadata (
  id                    INT AUTO_INCREMENT,
  domain_id             INT NOT NULL,
  kind                  VARCHAR(32),
  content               TEXT,
  PRIMARY KEY (id)
) Engine=InnoDB CHARACTER SET 'latin1';

CREATE INDEX domainmetadata_idx ON domainmetadata (domain_id, kind);
CREATE TABLE cryptokeys (
  id                    INT AUTO_INCREMENT,
  domain_id             INT NOT NULL,
  flags                 INT NOT NULL,
  active                BOOL,
  content               TEXT,
  PRIMARY KEY(id)
) Engine=InnoDB CHARACTER SET 'latin1';

CREATE INDEX domainidindex ON cryptokeys(domain_id);
CREATE TABLE tsigkeys (
  id                    INT AUTO_INCREMENT,
  name                  VARCHAR(255),
  algorithm             VARCHAR(50),
  secret                VARCHAR(255),
  PRIMARY KEY (id)
) Engine=InnoDB CHARACTER SET 'latin1';

CREATE UNIQUE INDEX namealgoindex ON tsigkeys(name, algorithm);
EOF

	#设置pdns配置文件
	cp /etc/pdns/pdns.conf /etc/pdns/pdns.conf_back
	cat >"/etc/pdns/pdns.conf"<<EOF
allow-axfr-ips=${slave_ip}
setgid=pdns
setuid=pdns
daemon=yes
master=yes
slave=no
disable-axfr=no
launch=gmysql
gmysql-host=127.0.0.1
gmysql-user=${db_user}
gmysql-password=${db_user_password}
gmysql-dbname=${db_name}
api=yes
api-key=${api_key}
gmysql-dnssec=yes
any-to-tcp=yes
resolver=114.114.114.114:53
expand-alias=yes
logging-facility=0
version-string=bind-9
max-queue-length=5000
max-cache-entries=1000000
max-tcp-connections=20
edns-subnet-processing=yes
udp-truncation-threshold=1680
default-soa-mail=admin.${host_name}
default-soa-name=${host_name}
EOF
systemctl enable pdns
systemctl start pdns
systemctl status pdns

elif [ ${action} -eq 2 ]; then
	read -p "输入主机名(完整的FQDN):" host_name 
	read -p "输入数据库管理员密码:" db_root_password
	read -p "输入需要创建的数据库用户名:" db_user
	read -p "输入需要创建的数据库用户密码:" db_user_password
	read -p "输入需要创建的数据库名:" db_name
	
	#设置主机名
	/usr/bin/hostnamectl set-hostname ${host_name}
	#安装pdns
	yum install epel-release yum-plugin-priorities mariadb -y
	curl -o /etc/yum.repos.d/powerdns-auth-master.repo https://repo.powerdns.com/repo-files/centos-auth-master.repo
	rpm --import https://repo.powerdns.com/CBC8B383-pub.asc
	yum install pdns pdns-backend-mysql -y

	#创建数据库已经pdns用户
	host=127.0.0.1
	username=root
	/usr/bin/mysql -h${host} -u ${username} -p${db_root_password} << EOF
CREATE DATABASE ${db_name};
GRANT ALL ON ${db_name}.* TO '${db_user}'@'%' IDENTIFIED BY '${db_user_password}';
FLUSH PRIVILEGES;
EOF
	#以下为创建pdns所需要用到的表
	/usr/bin/mysql -h${host} -u ${username} -p${db_root_password} -D ${db_name}<< EOF
CREATE TABLE domains (
  id                    INT AUTO_INCREMENT,
  name                  VARCHAR(255) NOT NULL,
  master                VARCHAR(128) DEFAULT NULL,
  last_check            INT DEFAULT NULL,
  type                  VARCHAR(6) NOT NULL,
  notified_serial       INT UNSIGNED DEFAULT NULL,
  account               VARCHAR(40) CHARACTER SET 'utf8' DEFAULT NULL,
  PRIMARY KEY (id)
) Engine=InnoDB CHARACTER SET 'latin1';

CREATE UNIQUE INDEX name_index ON domains(name);
CREATE TABLE records (
  id                    BIGINT AUTO_INCREMENT,
  domain_id             INT DEFAULT NULL,
  name                  VARCHAR(255) DEFAULT NULL,
  type                  VARCHAR(10) DEFAULT NULL,
  content               VARCHAR(64000) DEFAULT NULL,
  ttl                   INT DEFAULT NULL,
  prio                  INT DEFAULT NULL,
  change_date           INT DEFAULT NULL,
  disabled              TINYINT(1) DEFAULT 0,
  ordername             VARCHAR(255) BINARY DEFAULT NULL,
  auth                  TINYINT(1) DEFAULT 1,
  PRIMARY KEY (id)
) Engine=InnoDB CHARACTER SET 'latin1';

CREATE INDEX nametype_index ON records(name,type);
CREATE INDEX domain_id ON records(domain_id);
CREATE INDEX ordername ON records (ordername);
CREATE TABLE supermasters (
  ip                    VARCHAR(64) NOT NULL,
  nameserver            VARCHAR(255) NOT NULL,
  account               VARCHAR(40) CHARACTER SET 'utf8' NOT NULL,
  PRIMARY KEY (ip, nameserver)
) Engine=InnoDB CHARACTER SET 'latin1';
CREATE TABLE comments (
  id                    INT AUTO_INCREMENT,
  domain_id             INT NOT NULL,
  name                  VARCHAR(255) NOT NULL,
  type                  VARCHAR(10) NOT NULL,
  modified_at           INT NOT NULL,
  account               VARCHAR(40) CHARACTER SET 'utf8' DEFAULT NULL,
  comment               TEXT CHARACTER SET 'utf8' NOT NULL,
  PRIMARY KEY (id)
) Engine=InnoDB CHARACTER SET 'latin1';

CREATE INDEX comments_name_type_idx ON comments (name, type);
CREATE INDEX comments_order_idx ON comments (domain_id, modified_at);
CREATE TABLE domainmetadata (
  id                    INT AUTO_INCREMENT,
  domain_id             INT NOT NULL,
  kind                  VARCHAR(32),
  content               TEXT,
  PRIMARY KEY (id)
) Engine=InnoDB CHARACTER SET 'latin1';

CREATE INDEX domainmetadata_idx ON domainmetadata (domain_id, kind);
CREATE TABLE cryptokeys (
  id                    INT AUTO_INCREMENT,
  domain_id             INT NOT NULL,
  flags                 INT NOT NULL,
  active                BOOL,
  content               TEXT,
  PRIMARY KEY(id)
) Engine=InnoDB CHARACTER SET 'latin1';

CREATE INDEX domainidindex ON cryptokeys(domain_id);
CREATE TABLE tsigkeys (
  id                    INT AUTO_INCREMENT,
  name                  VARCHAR(255),
  algorithm             VARCHAR(50),
  secret                VARCHAR(255),
  PRIMARY KEY (id)
) Engine=InnoDB CHARACTER SET 'latin1';

CREATE UNIQUE INDEX namealgoindex ON tsigkeys(name, algorithm);
EOF

	#设置pdns配置文件
	cp /etc/pdns/pdns.conf /etc/pdns/pdns.conf_back
	cat >"/etc/pdns/pdns.conf"<<EOF
setgid=pdns
setuid=pdns
daemon=yes
slave=yes
master=no
launch=gmysql
gmysql-host=127.0.0.1
gmysql-user=${db_user}
gmysql-password=${db_user_password}
gmysql-dbname=${db_name}
gmysql-dnssec=yes
any-to-tcp=yes
resolver=114.114.114.114:53
expand-alias=yes
logging-facility=0
version-string=bind-9
max-queue-length=5000
max-cache-entries=1000000
max-tcp-connections=20
edns-subnet-processing=yes
udp-truncation-threshold=1680
slave-cycle-interval=60
supermaster=yes
EOF
systemctl enable pdns
systemctl start pdns
systemctl status pdns

elif [ ${action} -eq 3 ]; then
	echo -ne "\033[31m输入Slave服务器(完整的FQDN):\033[0m"
	read slave_host_name
	read -p "输入Master服务器IP:" master_ip
	read -p "输入数据库用户名:" db_user
	read -p "输入数据库用户密码:" db_user_password
	read -p "输入数据库名:" db_name	

	#配置Slave服务器
	host=127.0.0.1
	/usr/bin/mysql -h${host} -u ${db_user} -p${db_user_password} -D ${db_name}<< EOF
INSERT INTO supermasters VALUES ('${master_ip}', '${slave_host_name}', 'admin');
EOF
	if [ $? -eq 0 ]; then
		echo -e "\033[32m"Slave服务配置完成"\033[0m"
	else
		echo -e "\033[31m"请检查数据库信息"\033[0m"
	fi
fi


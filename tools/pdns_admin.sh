#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

. ./config.conf

echo -e "\033[33m"请选择下列选项进行安装"\033[0m"

echo "1:安装nginx"
echo "2:安装PowerDNS_Admin"
read -p "请输入选项进行安装:" action
#检测变量输入是否为空
if [ -z "${action}" ]; then
        echo -e "\033[31m"请从新运行$0此脚本，并输入选项进行安装."\033[0m"
        exit
fi
if [ "${action}" -eq 1 ]; then
	groupadd www
	useradd -M -s /sbin/nologin -g www www
	yum-config-manager --add-repo https://openresty.org/package/centos/openresty.repo -y
	yum install openresty -y
	rm -rf /usr/local/openresty/nginx/conf/nginx.conf
	wget -cP /usr/local/openresty/nginx/conf/ http://shell-pdns.test.upcdn.net/nginx/nginx.conf
	mkdir -p /usr/local/openresty/nginx/conf/vhost
	
	/usr/bin/firewall-cmd --zone=public --add-port=80/tcp --permanent
	/usr/bin/firewall-cmd --zone=public --add-port=443/tcp --permanent
	/usr/bin/firewall-cmd --reload
	systemctl enable openresty
	systemctl start openresty
fi

if [ "${action}" -eq 2 ]; then
	read -p "输入需要创建的数据库用户:" db_user
	read -p "输入需要创建的数据库用户密码:" db_user_password
	read -p "输入需要创建的数据库名:" db_name
#根据IP配置数据库源
	country=`curl -sSk --connect-timeout 30 -m 60 https://ip.vpser.net/country`
	echo "Server Location: ${country}"
	if [[ "${country}" = "CN" && ! -d "/root/.pip" ]]; then
		mkdir ~/.pip
		cat > ~/.pip/pip.conf <<EOF
[global]
index-url = https://pypi.doubanio.com/simple/

[install]
trusted-host=pypi.doubanio.com
EOF
	fi

	yum install python34 python34-devel python-pip gcc mariadb-devel openldap-devel xmlsec1-devel xmlsec1-openssl libtool-ltdl-devel -y

	pip install -U pip
	pip install -U virtualenv
	pip install python-dotenv
	
	curl -sL https://dl.yarnpkg.com/rpm/yarn.repo -o /etc/yum.repos.d/yarn.repo
	rpm --import https://dl.yarnpkg.com/rpm/pubkey.gpg
	yum install yarn -y
	
	if [ "${country}" = "CN" ]; then
		git clone https://gitee.com/m1911/PowerDNS-Admin.git ${PDNSAdmin_WEB_DIR}
	else
		git clone https://github.com/ngoduykhanh/PowerDNS-Admin.git ${PDNSAdmin_WEB_DIR}
	fi
	
	cd ${PDNSAdmin_WEB_DIR}
	virtualenv -p python3 flask
	source ./flask/bin/activate
	pip install -r requirements.txt
	cp config_template.py config.py

	username=root
	mysql -u ${username} -p${db_root_password} <<EOF
CREATE DATABASE ${db_name};
GRANT ALL ON ${db_name}.* TO '${db_user}'@'localhost' IDENTIFIED BY '${db_user_password}';
FLUSH PRIVILEGES;
EOF
	sed -i "s#BIND_ADDRESS = '127.0.0.1'#BIND_ADDRESS = '0.0.0.0'#" ${PDNSAdmin_WEB_DIR}/config.py
	sed -i "s#SQLA_DB_HOST = '127.0.0.1'#SQLA_DB_HOST = 'localhost'#" ${PDNSAdmin_WEB_DIR}/config.py
	sed -i "s#SQLA_DB_USER = 'pda'#SQLA_DB_USER = '${db_user}'#" ${PDNSAdmin_WEB_DIR}/config.py
	sed -i "s#SQLA_DB_PASSWORD = 'changeme'#SQLA_DB_PASSWORD = '${db_user_password}'#" ${PDNSAdmin_WEB_DIR}/config.py
	sed -i "s#SQLA_DB_NAME = 'pda'#SQLA_DB_NAME = '${db_name}'#" ${PDNSAdmin_WEB_DIR}/config.py

	export FLASK_APP=app/__init__.py
	flask db upgrade
	yarn install --pure-lockfile
	flask assets build

#Configuring Systemd and Gunicorn
	cat >"/etc/systemd/system/powerdns-admin.service"<<EOF
[Unit]
Description=PowerDNS-Admin
After=network.target

[Service]
User=root
Group=root
WorkingDirectory=${PDNSAdmin_WEB_DIR}
ExecStart=${PDNSAdmin_WEB_DIR}/flask/bin/gunicorn --workers 2 --bind unix:${PDNSAdmin_WEB_DIR}/powerdns-admin.sock app:app

[Install]
WantedBy=multi-user.target
EOF
	systemctl daemon-reload &&systemctl start powerdns-admin &&systemctl enable powerdns-admin
fi

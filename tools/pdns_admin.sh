#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

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
	yum install epel-release -y
	yum install nginx -y
	systemctl start nginx
	systemctl enable nginx
	systemctl status nginx
fi

if [ "${action}" -eq 2 ]; then
	read -p "输入数据库管理员密码:" db_root_password
	read -p "输入需要创建的数据库用户:" db_user
	read -p "输入需要创建的数据库用户密码:" db_user_password
	read -p "输入需要创建的数据库名:" db_name	
	read -p "输入PowerDNS_Admin Web安装目录:" web_dir
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


	yum install python34 python34-devel python-pip gcc git mariadb mariadb-devel openldap-devel xmlsec1-devel xmlsec1-openssl libtool-ltdl-devel -y

	pip install -U pip
	pip install -U virtualenv
	pip install python-dotenv
	
	curl -sL https://dl.yarnpkg.com/rpm/yarn.repo -o /etc/yum.repos.d/yarn.repo
	rpm --import https://dl.yarnpkg.com/rpm/pubkey.gpg
	yum install yarn -y
	
	if [ "${country}" = "CN" ]; then
		git clone https://gitee.com/m1911/PowerDNS-Admin.git ${web_dir}
	else
		git clone https://github.com/ngoduykhanh/PowerDNS-Admin.git ${web_dir}
	fi
	
	cd ${web_dir}
	virtualenv -p python3 flask
	source ./flask/bin/activate
	pip install -r requirements.txt
	cp config_template.py config.py

	host=127.0.0.1
	username=root
	mysql -h${host} -u ${username} -p${db_root_password} << EOF 2>/dev/null
CREATE DATABASE ${db_name};
GRANT ALL ON ${db_name}.* TO '${db_user}'@'%' IDENTIFIED BY '${db_user_password}';
FLUSH PRIVILEGES;
EOF
	sed -i "s#BIND_ADDRESS = '127.0.0.1'#BIND_ADDRESS = '0.0.0.0'#" ${web_dir}/config.py
	sed -i "s#SQLA_DB_USER = 'pda'#SQLA_DB_USER = '${db_user}'#" ${web_dir}/config.py
	sed -i "s#SQLA_DB_PASSWORD = 'changeme'#SQLA_DB_PASSWORD = '${db_user_password}'#" ${web_dir}/config.py
	sed -i "s#SQLA_DB_NAME = 'pda'#SQLA_DB_NAME = '${db_name}'#" ${web_dir}/config.py

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
WorkingDirectory=${web_dir}
ExecStart=${web_dir}/flask/bin/gunicorn --workers 2 --bind unix:${web_dir}/powerdns-admin.sock app:app

[Install]
WantedBy=multi-user.target
EOF
	systemctl daemon-reload &&systemctl start powerdns-admin &&systemctl enable powerdns-admin
fi

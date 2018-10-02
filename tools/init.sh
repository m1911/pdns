#!/bin/bash

Set_Timezone()
{
    rm -rf /etc/localtime
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
}

CentOS_InstallNTP()
{
    yum install -y ntp
    ntpdate -u pool.ntp.org
    date
    start_time=$(date +%s)
}


CentOS_RemoveAMP()
{
    rpm -qa|grep httpd
    rpm -e httpd httpd-tools --nodeps
    rpm -qa|grep mysql
    rpm -e mysql mysql-libs --nodeps
    rpm -qa|grep php
    rpm -e php-mysql php-cli php-gd php-common php --nodeps

	yum -y remove httpd*
    yum -y remove mysql-server mysql mysql-libs
    yum -y remove php*
}


CentOS_Modify_Source()
{
	country=`curl -sSk --connect-timeout 30 -m 60 https://ip.vpser.net/country`
	echo -e "\033[31mServer Location: ${country}\033[0m"
	if [ "${country}" = "CN" ]; then
		mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
		wget -cP /etc/yum.repos.d http://shell-pdns.test.upcdn.net/rpm/CentOS-Base.repo
		wget -cP /etc/yum.repos.d http://shell-pdns.test.upcdn.net/rpm/mariadb-cn.repo 
		rpm --import https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
		yum makecache
	else
		wget -cP /etc/yum.repos.d --no-check-certificate https://dl.ilankui.com/rpm/mariadb-us.repo
	fi
	
}

CentOS_Yum_tool()
{
	yum install wget socat unzip yum-utils git -y

}
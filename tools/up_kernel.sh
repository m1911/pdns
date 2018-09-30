#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

echo -e "\033[32m"请选择下列选项进行安装"\033[0m"
echo "1:升级稳定4.x版本内核"
echo "2:升级最新版本内核" 
read -p "请输入选项:" action
#检测变量输入是否为空
if [ -z "${action}" ]; then
	echo -e "\033[31m"请从新运行$0此脚本，并输入选项进行安装."\033[0m"
	exit
fi

country=`curl -sSk --connect-timeout 30 -m 60 https://ip.vpser.net/country`
echo "Server Location: ${country}"
if [ "${country}" = "CN" ]; then
	rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
	rpm -Uvh https://mirrors.tuna.tsinghua.edu.cn/elrepo/extras/el7/x86_64/RPMS/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
	yum update -y
else
	rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
    rpm -Uvh https://www.elrepo.org/elrepo-release-7.0-3.el7.elrepo.noarch.rpm
	yum update -y
fi

if [ "${action}" = 1 ]; then	
	yum --enablerepo=elrepo-kernel install kernel-lt -y
	grub2-set-default 0
elif [ "${action}" = 2 ]; then
	yum --enablerepo=elrepo-kernel install kernel-ml -y
	grub2-set-default 0
fi

if [ $? -eq 0 ]; then
	read -p "内核升级成功需要重启生效，是否重启(y|n):" is_reboot
	if [[ ${is_reboot} == "y" || ${is_reboot} == "Y" ]]; then
        reboot
	else
		echo -e "\033[32m"请自行手动重启服务器"\033[0m"
		exit
	fi
fi

#!/bin/bash
# System Required:  CentOS 7
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#检测是否是root用户
if [ $(id -u) != "0" ]; then
	echo "错误：必须使用Root用户才能执行此脚本."
	exit 1
fi

. tools/init.sh
echo -n "是否安装必要的工具(y/n):"
read install
if [[ -f "/usr/bin/yum" && ${install} = y ]];then
	Set_Timezone
	CentOS_InstallNTP
	CentOS_Modify_Source
	CentOS_Yum_tool
	CentOS_Install_firewall
fi
	
echo -e "\033[33m"请选择下列选项进行安装"\033[0m"

echo "1:更新系统和升级Linux内核"
echo "2:安装Docker和Docker-compose"
echo "3:安装MariaDB(Yum安装方式)"
echo "4:安装PowerDNS"
echo "5:安装PowerDNS_Admin(Python)"
echo "6:添加虚拟机"
echo "7:卸载旧内核(只是卸载3.x旧内核)"
echo "0:退出安装"

read -p "请输入选项进行安装:" action
#检测变量输入是否为空
if [ -z "${action}" ]; then
        echo -e "\033[31m"请从新运行$0此脚本，并输入选项进行安装."\033[0m"
        exit;
fi

if [ ${action} -eq 1 ]; then
	sh tools/up_kernel.sh 2>&1 | tee /tmp/up_kernel.log
elif [ ${action} -eq 2 ]; then
	sh tools/docker.sh 2>&1 | tee /tmp/docker_install.log
elif [ ${action} -eq 3 ]; then
	sh tools/mariadb.sh 2>&1 | tee /tmp/mariadb_install.log
elif [ ${action} -eq 4 ]; then
	sh tools/pdns.sh 2>&1 | tee /tmp/pdns_install.log
elif [ ${action} -eq 5 ]; then
	sh tools/pdns_admin.sh 2>&1 | tee /tmp/pdns_admin_install.log
elif [ ${action} -eq 6 ]; then
	sh tools/vhost.sh
elif [ ${action} -eq 7 ]; then
	yum autoremove kernel-3.10.0-* -y
fi
if [ ${action} -eq 0 ]; then
	exit
fi

#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun

country=`curl -sSk --connect-timeout 30 -m 60 https://ip.vpser.net/country`
echo "Server Location: ${country}"
if [ "${country}" = "CN" ]; then
	wget -c https://dl.ilankui.com/docker/docker-compose-Linux-x86_64 -O /usr/local/bin/docker-compose
else
	wget -c https://github.com/docker/compose/releases/download/1.22.0/docker-compose-Linux-x86_64 -O /usr/local/bin/docker-compose
fi

chmod +x /usr/local/bin/docker-compose

systemctl start docker

if [ "${country}" = "CN" ]; then
	curl -sSL https://get.daocloud.io/daotools/set_mirror.sh | sh -s http://f1361db2.m.daocloud.io
	systemctl restart docker
else
	systemctl status docker
    exit	
fi

systemctl enable docker

if [ $? -eq 0 ]; then
	echo -e "\033[32m"Docker安装成功"\033[0m"
else
	exit
fi

#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

. ./directory.conf

echo -e "\033[33m"此脚本只适用PowerDNS_Admin虚拟机添加"\033[0m"
read -p "请输入域名:" domain
#检测变量输入是否为空
if [ -z "${domain}" ]; then
        echo -e "\033[31m"请从新运行$0此脚本，域名不允许为空."\033[0m"
        exit
fi
if [ ! -f "/usr/local/openresty/nginx/conf/vhost/${domain}.conf" ]; then
	read -p "输入更多域名:" moredomain
	read -p "输入网站目录:" web_dir
	if [ -z ${moredomain} ]; then
		cat >"/usr/local/openresty/nginx/conf/vhost/${domain}.conf"<<EOF
server {
  listen 80;
  server_name	${domain};

  index                     index.html index.htm index.php;
  root                      ${web_dir};
  access_log                logs/${domain}.access.log combined;
  error_log                 logs/${domain}.error.log;

  client_max_body_size              10m;
  client_body_buffer_size           128k;
  proxy_redirect                    off;
  proxy_connect_timeout             90;
  proxy_send_timeout                90;
  proxy_read_timeout                90;
  proxy_buffers                     32 4k;
  proxy_buffer_size                 8k;
  proxy_set_header                  Host \$host;
  proxy_set_header                  X-Real-IP \$remote_addr;
  proxy_set_header                  X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_headers_hash_bucket_size    64;

  location ~ ^/static/  {
    #include  /usr/local/openresty/nginx/conf/mime.types;
    root ${web_dir}/app;

    location ~*  \.(jpg|jpeg|png|gif)$ {
      expires 30d;
    }

    location ~* ^.+.(css|js)$ {
      expires 12h;
    }
  }

  location / {
    proxy_pass            http://unix:${web_dir}/powerdns-admin.sock;
    proxy_read_timeout    120;
    proxy_connect_timeout 120;
    proxy_redirect        off;
  }

}
EOF
	ln -sf ${PDNSAdmin_WEB_DIR} ${web_dir}
	/usr/local/openresty/nginx/sbin/nginx -s reload
	else
	cat >"/usr/local/openresty/nginx/conf/vhost/${domain}.conf"<<EOF
server {
  listen 80;
  server_name	${domain} ${moredomain};

  index                     index.html index.htm index.php;
  root                      ${web_dir};
  access_log                logs/${domain}.access.log combined;
  error_log                 logs/${domain}.error.log;

  client_max_body_size              10m;
  client_body_buffer_size           128k;
  proxy_redirect                    off;
  proxy_connect_timeout             90;
  proxy_send_timeout                90;
  proxy_read_timeout                90;
  proxy_buffers                     32 4k;
  proxy_buffer_size                 8k;
  proxy_set_header                  Host \$host;
  proxy_set_header                  X-Real-IP \$remote_addr;
  proxy_set_header                  X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_headers_hash_bucket_size    64;

  location ~ ^/static/  {
    #include  /usr/local/openresty/nginx/conf/mime.types;
    root ${web_dir}/app;

    location ~*  \.(jpg|jpeg|png|gif)$ {
      expires 30d;
    }

    location ~* ^.+.(css|js)$ {
      expires 12h;
    }
  }

  location / {
    proxy_pass            http://unix:${web_dir}/powerdns-admin.sock;
    proxy_read_timeout    120;
    proxy_connect_timeout 120;
    proxy_redirect        off;
  }

}
EOF
	ln -sf ${PDNSAdmin_WEB_DIR} ${web_dir}
	/usr/local/openresty/nginx/sbin/nginx -s reload
	fi
	if [ $? -eq 0 ]; then
		echo -e "\033[32m"虚拟机添加成功"\033[0m"
	fi
else
	read -p  "输入的域名已经存在，是否删除.(y/n)" action
	if [[ "${action}" = n && "${action}" = "" ]]; then
		exit
	else
		rm -rf /usr/local/openresty/nginx/conf/vhost/${domain}.conf
		echo -e "\033[32m"域名已经删除成功"\033[0m"
	fi
fi

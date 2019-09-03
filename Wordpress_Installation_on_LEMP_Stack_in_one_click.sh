#!/bin/bash
# Author - Akshay Gupta
# Version - 2.0.0
# Description - Installs and Configures LEMP Stack and then Wordpress for Port 80 only, in just 1 click.
# In Version 2.0.0 -> Manual/Automatic installation of Wordpress on LEMP Stack is available
# Usage -
#
#	bash Wordpress_Installation_on_LEMP_Stack_in_one_click.sh
#	bash Wordpress_Installation_on_LEMP_Stack_in_one_click.sh 1
#	bash Wordpress_Installation_on_LEMP_Stack_in_one_click.sh 2
#

installations() {
	if [ $(date | awk '{print $2 $3}') != $(ls -al /var/lib/apt/periodic/update-success-stamp | awk '{print $6 $7}') ]
	then
		apt update -y
		apt upgrade -y
		apt dist-upgrade -y
	fi
	apt install -y software-properties-common;
	add-apt-repository -y ppa:ondrej/php;
	apt update -y;
	apt install nginx -y;
	apt install php7.1-mcrypt php7.1-intl php7.1-curl php7.1-xsl php7.1-mbstring php7.1-xsl php7.1-zip php7.1-soap php7.1-gd php7.1-bcmath php7.1-mysql php7.1-fpm -y;
	apt install mysql-server mysql-client -y;
	apt install composer -y;
}

conf_php() {
sed -i 's/memory_limit = -1/memory_limit = 2G/g' /etc/php/7.1/cli/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 1800/g' /etc/php/7.1/cli/php.ini
sed -i 's/zlib.output_compression = Off/zlib.output_compression = On/g' /etc/php/7.1/cli/php.ini

cat /etc/php/7.1/cli/php.ini | grep memory_limit
cat /etc/php/7.1/cli/php.ini | grep max_execution_time
cat /etc/php/7.1/cli/php.ini | grep 'zlib.output_compression ='

sed -i 's/memory_limit = 128M/memory_limit = 2G/g' /etc/php/7.1/fpm/php.ini
sed -i 's/max_execution_time = 30/max_execution_time = 1800/g' /etc/php/7.1/fpm/php.ini
sed -i 's/zlib.output_compression = Off/zlib.output_compression = On/g' /etc/php/7.1/fpm/php.ini

cat /etc/php/7.1/fpm/php.ini | grep memory_limit
cat /etc/php/7.1/fpm/php.ini | grep max_execution_time
cat /etc/php/7.1/fpm/php.ini | grep 'zlib.output_compression ='
service php7.1-fpm restart
}

conf_nginx() {

mkdir -p $root_dir;
if [[ ! -e /etc/nginx/php_loc.conf ]]; then
cat >> /etc/nginx/php_loc.conf << PHP_BLOCK
#	pass PHP scripts to FastCGI server
	location ~ \.php$ {
	root           $root_dir;
	fastcgi_index  index.php;
	try_files \$uri =404;
#	With php-fpm (or other unix sockets):
	fastcgi_pass fastcgi_backend;
	include        fastcgi_params;
	fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
}
PHP_BLOCK
fi

if [[ ! -e /etc/nginx/sites-available/$nginx_conf ]]; then
	cp /etc/nginx/sites-available/default /etc/nginx/sites-available/$nginx_conf;

	# converting /dir1/dir2/ to \/dir1\/dir2\/, so that it can be added properly in /etc/nginx/sites-available/website conf file
	root_dir2=${root_dir////\\/}

cat >> /etc/nginx/sites-available/$nginx_conf.tmp << UPSTREAM
upstream fastcgi_backend {
	server  unix:/run/php/php7.1-fpm.sock;
}
UPSTREAM
	cat /etc/nginx/sites-available/$nginx_conf.tmp /etc/nginx/sites-available/$nginx_conf > /etc/nginx/sites-available/$nginx_conf.new;
	mv /etc/nginx/sites-available/$nginx_conf.new /etc/nginx/sites-available/$nginx_conf;
	rm -rf /etc/nginx/sites-available/$nginx_conf.tmp;
	sed -i "s/fastcgi_pass 127.0.0.1:9000/fastcgi_pass 127.0.0.1:9000;\
	\ninclude \/etc\/nginx\/php_loc.conf/g" /etc/nginx/sites-available/$nginx_conf;
	sed -i "s/root \/var\/www\/html/root $root_dir2/g" /etc/nginx/sites-available/$nginx_conf;
	sed -i "s/index index.html index.htm index.nginx-debian.html/index index.php index.html index.htm index.nginx-debian.html/g" /etc/nginx/sites-available/$nginx_conf;
	sed -i "s/\include \/etc\/nginx\/sites-enabled\//include \/etc\/nginx\/sites-enabled\/$nginx_conf;\
	\n#/g" /etc/nginx/nginx.conf;
fi
if [[ ! -e /etc/nginx/sites-enabled/$nginx_conf ]]; then
	ln -s /etc/nginx/sites-available/$nginx_conf /etc/nginx/sites-enabled/;
fi
if [[ ! -e $root_dir/test.php ]]; then
	echo '<?php phpinfo(); ?>' > $root_dir/test.php;
fi
service nginx restart
}

conf_db() {

	mysql -h $host -u $rt_user --password=$rt_pw -e "
	CREATE DATABASE $db_name;
	CREATE USER '$user_name'@'%' IDENTIFIED BY '$pw';
	GRANT ALL PRIVILEGES ON $db_name.* TO '$user_name'@'%';
	FLUSH PRIVILEGES;"
}

conf_wp() {
	cd /root/
if [[ ! -e latest.tar.gz ]]; then
	wget http://wordpress.org/latest.tar.gz -O latest.tar.gz
fi
if [[ ! -d wordpress ]]; then
	tar xzf latest.tar.gz
fi

	cd wordpress
if [[ ! -e wp-config.php ]]; then
	cp wp-config-sample.php wp-config.php
	sed -i "s/define( 'DB_NAME', 'database_name_here' )/define( 'DB_NAME', '$db_name' )/g" wp-config.php
	sed -i "s/define( 'DB_USER', 'username_here' )/define( 'DB_USER', '$user_name' )/g" wp-config.php
	sed -i "s/define( 'DB_PASSWORD', 'password_here' )/define( 'DB_PASSWORD', '$pw' )/g" wp-config.php
	sed -i "s/define( 'DB_HOST', 'localhost' )/define( 'DB_PASSWORD', '$host' )/g" wp-config.php
	
	# To give permissions to wp-content to install plugins/themes etc
	echo "define('FS_METHOD', 'direct');" >> wp-config.php
fi
	cd /root/
	cp wordpress/* $root_dir -r
	mkdir -p $root_dir/wp-content/uploads
	chown -R www-data:www-data $root_dir/*
	find $root_dir -type d -exec chmod 755 {} \;
	find $root_dir -type f -exec chmod 644 {} \;
	rm -rf /etc/nginx/sites-enabled/$nginx_conf;
	ln -s /etc/nginx/sites-available/$nginx_conf /etc/nginx/sites-enabled/;
	service nginx restart;
}

echo "1. To install and configure LEMP Stack and Wordpress on it with user defined values."
echo "2. To install and configure LEMP Stack and Wordpress on it with default values."
echo -e "\nDefault Choice is 2."

if [ -z $1 ]; then
	read choice
fi

if [ -z $choice ]; then
	choice="$1"
fi

case $choice in
1)
clear
echo "=====================START=========================="				>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Updates, Upgrades and Distribution Upgrades"					>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Updating, Upgrading and Installing Distribution Upgrades"
installations										>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Configuring php.ini for nginx and Wordpress"					>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Configuring php.ini for nginx and Wordpress"
conf_php										>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Configuring nginx.conf and sites-available/website for php and Wordpress"		>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Configuring nginx.conf and sites-available/website for php and Wordpress"

echo "Enter location of www-data root directory. . (Default: /var/www/html/website)"
read root_dir
if [ -z $root_dir ]; then
	root_dir='/var/www/html/website'
fi
echo "Enter name (only name not location) of configuration file under /etc/nginx/sites-available/. (Default: website)"
read nginx_conf

if [ -z $nginx_conf ]; then
	nginx_conf='website'
fi

conf_nginx										>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Creating DB and User"								>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Creating DB and User"

echo "Enter host IP/Endpoint/DNS: (Default: localhost)"
read host
if [ -z $host ]; then
	host='localhost'
fi
echo "Enter Master username to make connection to MySQL: (Default: root)"
read rt_user
if [ -z $rt_user ]; then
	rt_user='root'
fi
echo "Enter Password of Master username to make connection to MySQL: (Default: NULL/EMPTY)"
read rt_pw
if [ -z $rt_pw ]; then
	rt_pw=''
fi
echo 'Enter name of Database you want to be created: (Default: websiteDB)'
read db_name
if [ -z $db_name ]; then
	db_name='websiteDB'
fi
echo 'Enter name of User you want to be created: (Default: admin)'
read user_name
if [ -z $user_name ]; then
	user_name='admin'
fi
echo "Enter Password for $user_name: (Default: password)"
read pw
if [ -z $pw ]; then
	pw='password'
fi

conf_db											>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Downloading and setting up latest Wordpress version"				>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Downloading and setting up latest Wordpress version"
conf_wp											>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "======================END==========================="				>> /root/wordpress_lemp_stack_setup.log  2>&1

echo "root Directory:					$root_dir"
echo "Website's nginx Configuration File:		$nginx_conf"
echo "Database Name: 					$db_name"
echo "Username: 					$user_name"
echo "Password: 					$pw"
echo "Database Host: 					$host"

exit
;;
2)
clear

root_dir='/var/www/html/website'
nginx_conf='website'
db_name='websiteDB'
user_name='admin'
pw='password'

echo "=====================START=========================="				>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Updates, Upgrades and Distribution Upgrades"					>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Updating, Upgrading and Installing Distribution Upgrades"
installations										>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Configuring php.ini for nginx and Wordpress"					>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Configuring php.ini for nginx and Wordpress"
conf_php										>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Configuring nginx.conf and sites-available/website for php and Wordpress"		>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Configuring nginx.conf and sites-available/website for php and Wordpress"
conf_nginx										>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Creating DB and User"								>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Creating DB and User"
conf_db											>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Downloading and setting up latest Wordpress version"				>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "Downloading and setting up latest Wordpress version"
conf_wp											>> /root/wordpress_lemp_stack_setup.log  2>&1
echo "======================END==========================="				>> /root/wordpress_lemp_stack_setup.log  2>&1

echo "root Directory:					$root_dir"
echo "Website's nginx Configuration File:		$nginx_conf"
echo "Database Name: 					$db_name"
echo "Username: 					$user_name"
echo "Password: 					$pw"
echo "Database Host: 					$host"


exit
;;
*)
loc="$(readlink -f ${BASH_SOURCE[0]})"
echo "Running $loc with Choice 2"
read -p "Press Enter to continue" </dev/tty
bash $loc 2
;;
esac

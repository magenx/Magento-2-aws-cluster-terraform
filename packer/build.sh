#!/bin/bash
#=================================================================================#
#        MagenX e-commerce stack for Magento 2                                    #
#        Copyright (C) 2013-present admin@magenx.com                              #
#        All rights reserved.                                                     #
#=================================================================================#

AWSTOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: ${AWSTOKEN}" http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_TYPE=$(curl -s -H "X-aws-ec2-metadata-token: ${AWSTOKEN}" http://169.254.169.254/latest/meta-data/instance-type)

## installation
sudo apt-get update
sudo apt-get -qqy install ${LINUX_PACKAGES}
sudo pip3 install git-remote-codecommit

## create user
sudo useradd -d /home/${BRAND} -s /sbin/nologin ${BRAND}
## create root php user
sudo useradd -M -s /sbin/nologin -d /home/${BRAND} ${PHP_USER}
sudo usermod -g ${PHP_USER} ${BRAND}
 
sudo mkdir -p ${WEB_ROOT_PATH}
sudo chmod 711 /home/${BRAND}
sudo mkdir -p /home/${BRAND}/{.config,.cache,.local,.composer}
sudo chown -R ${BRAND}:${PHP_USER} ${WEB_ROOT_PATH}
sudo chown -R ${BRAND}:${BRAND} /home/${BRAND}/{.config,.cache,.local,.composer}
sudo chmod 2770 ${WEB_ROOT_PATH} /home/${BRAND}/{.config,.cache,.local,.composer}
sudo setfacl -R -m u:${BRAND}:rwX,g:${PHP_USER}:r-X,o::-,d:u:${BRAND}:rwX,d:g:${PHP_USER}:r-X,d:o::- ${WEB_ROOT_PATH}

sudo sh -c "echo '${EFS_DNS_TARGET}:/data/var ${WEB_ROOT_PATH}/var nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0' >> /etc/fstab"
sudo sh -c "echo '${EFS_DNS_TARGET}:/data/pub/media ${WEB_ROOT_PATH}/pub/media nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0' >> /etc/fstab"

sudo mkdir -p ${WEB_ROOT_PATH}/{pub/media,var}
sudo chown -R ${BRAND}:${PHP_USER} ${WEB_ROOT_PATH}/
sudo chmod 2770 ${WEB_ROOT_PATH}/{pub/media,var}

## install nginx
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/debian `lsb_release -cs` nginx" > /etc/apt/sources.list.d/nginx.list'

## install php + phpmyadmin
sudo wget -qO /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
sudo sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'

sudo apt-get -qq update -o Dir::Etc::sourcelist="sources.list.d/nginx.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
sudo apt-get -qq update -o Dir::Etc::sourcelist="sources.list.d/php.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
 
_PHP_PACKAGES+=(${PHP_PACKAGES})
sudo apt-get -qqy install nginx php-pear php${PHP_VERSION} ${_PHP_PACKAGES[@]/#/php${PHP_VERSION}-}

sudo setfacl -R -m u:nginx:r-X,g:nginx:r-X,d:u:nginx:r-X ${WEB_ROOT_PATH}

sudo sh -c "cat > /etc/sysctl.conf <<END
fs.file-max = 1000000
fs.inotify.max_user_watches = 1000000
vm.swappiness = 5
net.ipv4.ip_forward = 0
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.default.accept_source_route = 0
kernel.sysrq = 0
kernel.core_uses_pid = 1
kernel.msgmnb = 65535
kernel.msgmax = 65535
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_mem = 8388608 8388608 8388608
net.ipv4.tcp_rmem = 4096 87380 8388608
net.ipv4.tcp_wmem = 4096 65535 8388608
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_challenge_ack_limit = 1073741823
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 15
net.ipv4.tcp_max_orphans = 262144
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_max_tw_buckets = 400000
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_sack = 1
net.ipv4.route.flush = 1
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.rmem_default = 8388608
net.core.wmem_default = 8388608
net.core.netdev_max_backlog = 262144
net.core.somaxconn = 65535
END
"


sudo sh -c "cat > ${PHP_OPCACHE_INI} <<END
zend_extension=opcache.so
opcache.enable = 1
opcache.enable_cli = 1
opcache.memory_consumption = 512
opcache.interned_strings_buffer = 4
opcache.max_accelerated_files = 60000
opcache.max_wasted_percentage = 5
opcache.use_cwd = 1
opcache.validate_timestamps = 0
;opcache.revalidate_freq = 2
;opcache.validate_permission = 1
opcache.validate_root = 1
opcache.file_update_protection = 2
opcache.revalidate_path = 0
opcache.save_comments = 1
opcache.load_comments = 1
opcache.fast_shutdown = 1
opcache.enable_file_override = 0
opcache.optimization_level = 0xffffffff
opcache.inherited_hack = 1
opcache.max_file_size = 0
opcache.consistency_checks = 0
opcache.force_restart_timeout = 60
opcache.error_log = "/var/log/php-fpm/opcache.log"
opcache.log_verbosity_level = 1
opcache.preferred_memory_model = ""
opcache.protect_memory = 0
;opcache.mmap_base = ""
END
"

sudo sh -c "cp ${PHP_INI} ${PHP_INI}.BACK"
sudo sed -i 's/^\(max_execution_time = \)[0-9]*/\17200/' ${PHP_INI}
sudo sed -i 's/^\(max_input_time = \)[0-9]*/\17200/' ${PHP_INI}
sudo sed -i 's/^\(memory_limit = \)[0-9]*M/\12048M/' ${PHP_INI}
sudo sed -i 's/^\(post_max_size = \)[0-9]*M/\164M/' ${PHP_INI}
sudo sed -i 's/^\(upload_max_filesize = \)[0-9]*M/\132M/' ${PHP_INI}
sudo sed -i 's/expose_php = On/expose_php = Off/' ${PHP_INI}
sudo sed -i 's/;realpath_cache_size =.*/realpath_cache_size = 5M/' ${PHP_INI}
sudo sed -i 's/;realpath_cache_ttl =.*/realpath_cache_ttl = 86400/' ${PHP_INI}
sudo sed -i 's/short_open_tag = Off/short_open_tag = On/' ${PHP_INI}
sudo sed -i 's/;max_input_vars =.*/max_input_vars = 50000/' ${PHP_INI}
sudo sed -i 's/session.gc_maxlifetime = 1440/session.gc_maxlifetime = 28800/' ${PHP_INI}
sudo sed -i 's/mysql.allow_persistent = On/mysql.allow_persistent = Off/' ${PHP_INI}
sudo sed -i 's/mysqli.allow_persistent = On/mysqli.allow_persistent = Off/' ${PHP_INI}
sudo sed -i 's/pm = dynamic/pm = ondemand/' ${PHP_FPM_POOL}
sudo sed -i 's/;pm.max_requests = 500/pm.max_requests = 10000/' ${PHP_FPM_POOL}
sudo sed -i 's/^\(pm.max_children = \)[0-9]*/\1100/' ${PHP_FPM_POOL}

sudo sed -i "s/\[www\]/\[${BRAND}\]/" ${PHP_FPM_POOL}
sudo sed -i "s/^user =.*/user = ${PHP_USER}/" ${PHP_FPM_POOL}
sudo sed -i "s/^group =.*/group = ${PHP_USER}/" ${PHP_FPM_POOL}
sudo sed -ri "s/;?listen.owner =.*/listen.owner = ${BRAND}/" ${PHP_FPM_POOL}
sudo sed -ri "s/;?listen.group =.*/listen.group = ${PHP_USER}/" ${PHP_FPM_POOL}
sudo sed -ri "s/;?listen.mode = 0660/listen.mode = 0660/" ${PHP_FPM_POOL}
sudo sed -ri "s/;?listen.allowed_clients =.*/listen.allowed_clients = 127.0.0.1/" ${PHP_FPM_POOL}
sudo sed -i '/sendmail_path/,$d' ${PHP_FPM_POOL}
sudo sed -i '/PHPSESSID/d' ${PHP_INI}
sudo sed -i "s,.*date.timezone.*,date.timezone = ${TIMEZONE}," ${PHP_INI}

sudo sh -c 'cat >> ${PHP_FPM_POOL} <<END
;;
;; Custom pool settings
php_flag[display_errors] = off
php_admin_flag[log_errors] = on
php_admin_value[error_log] = "${WEB_ROOT_PATH}/var/log/php-fpm-error.log"
php_admin_value[default_charset] = UTF-8
php_admin_value[memory_limit] = 2048M
php_admin_value[date.timezone] = ${TIMEZONE}
END
'

cd /etc/nginx
sudo git init
sudo git remote add origin ${CODECOMMIT_SERVICES_REPO}
sudo git fetch
sudo git reset --hard origin/nginx_${INSTANCE_NAME}
sudo git checkout -t origin/nginx_${INSTANCE_NAME}

if [ "${INSTANCE_NAME}" == "admin" ]; then
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/internal/skip-preseed boolean true"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean false"

sudo apt-get -qqy install composer mariadb-client phpmyadmin
 
sudo sh -c "cp /usr/share/phpmyadmin/config.sample.inc.php /etc/phpmyadmin/config.inc.php"
sudo sed -i "s/.*blowfish_secret.*/\$cfg['blowfish_secret'] = '${BLOWFISH}';/" /etc/phpmyadmin/config.inc.php
sudo sed -i "s/localhost/${DATABASE_ENDPOINT}/" /etc/phpmyadmin/config.inc.php
sudo sed -i "s/PHPMYADMIN_PLACEHOLDER/${MYSQL_PATH}/g" /etc/nginx/conf.d/phpmyadmin.conf
sudo sed -i "s,#include conf.d/phpmyadmin.conf;,include conf.d/phpmyadmin.conf;," /etc/nginx/sites-available/magento.conf
 
sudo sh -c 'cat > /etc/logrotate.d/magento <<END
${WEB_ROOT_PATH}/var/log/*.log
{
su ${BRAND} ${PHP_USER}
create 660 ${BRAND} ${PHP_USER}
daily
rotate 7
notifempty
missingok
compress
}
END
'
fi

sudo mkdir -p /etc/nginx/sites-enabled
sudo ln -s /etc/nginx/sites-available/magento.conf /etc/nginx/sites-enabled/magento.conf
 
sudo sed -i "s,CIDR,${CIDR}," /etc/nginx/nginx.conf
sudo sed -i "s/HEALTH_CHECK_LOCATION/${HEALTH_CHECK_LOCATION}/" /etc/nginx/sites-available/magento.conf
sudo sed -i "s,/var/www/html,${WEB_ROOT_PATH},g" /etc/nginx/conf.d/maps.conf
sudo sed -i "s/PROFILER_PLACEHOLDER/${PROFILER}/" /etc/nginx/conf.d/maps.conf
sudo sh -c "echo '' > /etc/nginx/conf.d/default.conf"
 
sudo sed -i "s/example.com/${DOMAIN}/g" /etc/nginx/sites-available/magento.conf
sudo sed -i "s/example.com/${DOMAIN}/g" /etc/nginx/nginx.conf
 
sudo timedatectl set-timezone ${TIMEZONE}
 
cd /tmp
sudo wget https://aws-codedeploy-${AWS_DEFAULT_REGION}.s3.amazonaws.com/latest/install
sudo chmod +x ./install
sudo ./install auto
 
sudo wget https://s3.${AWS_DEFAULT_REGION}.amazonaws.com/amazon-ssm-${AWS_DEFAULT_REGION}/latest/debian_arm64/amazon-ssm-agent.deb
sudo dpkg -i amazon-ssm-agent.deb
sudo systemctl enable amazon-ssm-agent

sudo wget https://s3.${AWS_DEFAULT_REGION}.amazonaws.com/amazoncloudwatch-agent-${AWS_DEFAULT_REGION}/ubuntu/arm64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:amazon-cloudwatch-agent-${INSTANCE_NAME}.json

sudo chmod 750 /usr/bin/aws
sudo apt-get clean

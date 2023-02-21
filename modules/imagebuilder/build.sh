#!/bin/bash

## debug
if [ -z "${_PARAMETERSTORE_NAME}" ]; then
echo "_PARAMETERSTORE_NAME is empty"
exit 1
fi

## remove old aws cli v1
apt-get -y remove awscli
apt-get update
apt-get -qqy install jq unzip

## get latest aws cli v2
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip -d /root/
rm awscliv2.zip
/root/aws/install --bin-dir /usr/bin --install-dir /root/aws --update
rm -rf /root/aws/{dist,install}

## get environment variables from aws parameter store
_PARAMETER=$(aws ssm get-parameter --name "${_PARAMETERSTORE_NAME}" --query 'Parameter.Value' --output text)
declare -A parameter
while IFS== read -r key value; do parameter["$key"]="$value"; done < <(echo ${_PARAMETER} | jq -r 'to_entries[] | .key + "=" + .value')

## installation
apt-get -qqy install ${parameter["LINUX_PACKAGES"]}
pip3 install git-remote-codecommit

## create user
useradd -d /home/${parameter["BRAND"]} -s /sbin/nologin ${parameter["BRAND"]}
## create root php user
useradd -M -s /sbin/nologin -d /home/${parameter["BRAND"]} ${parameter["PHP_USER"]}
usermod -g ${parameter["PHP_USER"]} ${parameter["BRAND"]}
 
mkdir -p ${parameter["WEB_ROOT_PATH"]}
chmod 711 /home/${parameter["BRAND"]}
mkdir -p /home/${parameter["BRAND"]}/{.config,.cache,.local,.composer}
chown -R ${parameter["BRAND"]}:${parameter["PHP_USER"]} ${parameter["WEB_ROOT_PATH"]}
chown -R ${parameter["BRAND"]}:${parameter["BRAND"]} /home/${parameter["BRAND"]}/{.config,.cache,.local,.composer}
chmod 2750 ${parameter["WEB_ROOT_PATH"]} /home/${parameter["BRAND"]}/{.config,.cache,.local,.composer}
setfacl -R -m m:rx,u:${parameter["BRAND"]}:rwX,g:${parameter["PHP_USER"]}:r-X,o::-,d:u:${parameter["BRAND"]}:rwX,d:g:${parameter["PHP_USER"]}:r-X,d:o::- ${parameter["WEB_ROOT_PATH"]}

## add EFS mount
mkdir -p /mnt/efs
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 ${parameter["EFS_DNS_TARGET"]}:/ /mnt/efs
mkdir -p /mnt/efs/data/{var,pub/media}
chown -R ${parameter["BRAND"]}:${parameter["PHP_USER"]} /mnt/efs/
find /mnt/efs -type d -exec chmod 2770 {} \;
umount /mnt/efs

echo "${parameter["EFS_DNS_TARGET"]}:/data/var ${parameter["WEB_ROOT_PATH"]}/var nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab
echo "${parameter["EFS_DNS_TARGET"]}:/data/pub/media ${parameter["WEB_ROOT_PATH"]}/pub/media nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,_netdev 0 0" >> /etc/fstab

mkdir -p ${parameter["WEB_ROOT_PATH"]}/{pub/media,var}
chown -R ${parameter["BRAND"]}:${parameter["PHP_USER"]} ${parameter["WEB_ROOT_PATH"]}/
chmod 2770 ${parameter["WEB_ROOT_PATH"]}/{pub/media,var}

## install nginx
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/debian `lsb_release -cs` nginx" > /etc/apt/sources.list.d/nginx.list

## install php + phpmyadmin
wget -qO /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list

apt-get -qq update -o Dir::Etc::sourcelist="sources.list.d/nginx.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"
apt-get -qq update -o Dir::Etc::sourcelist="sources.list.d/php.list" -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"

_PHP_PACKAGES+=(${parameter["PHP_PACKAGES"]})
apt-get -qqy install nginx php-pear php${parameter["PHP_VERSION"]} ${_PHP_PACKAGES[@]/#/php${parameter["PHP_VERSION"]}-}

setfacl -R -m u:nginx:r-X,d:u:nginx:r-X ${parameter["WEB_ROOT_PATH"]}

cat > /etc/sysctl.conf <<END
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

cat > ${parameter["PHP_OPCACHE_INI"]} <<END
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

cp ${parameter["PHP_INI"]} ${parameter["PHP_INI"]}.BACK
sed -i 's/^\(max_execution_time = \)[0-9]*/\17200/' ${parameter["PHP_INI"]}
sed -i 's/^\(max_input_time = \)[0-9]*/\17200/' ${parameter["PHP_INI"]}
sed -i 's/^\(memory_limit = \)[0-9]*M/\11048M/' ${parameter["PHP_INI"]}
sed -i 's/^\(post_max_size = \)[0-9]*M/\164M/' ${parameter["PHP_INI"]}
sed -i 's/^\(upload_max_filesize = \)[0-9]*M/\132M/' ${parameter["PHP_INI"]}
sed -i 's/expose_php = On/expose_php = Off/' ${parameter["PHP_INI"]}
sed -i 's/;realpath_cache_size =.*/realpath_cache_size = 5M/' ${parameter["PHP_INI"]}
sed -i 's/;realpath_cache_ttl =.*/realpath_cache_ttl = 86400/' ${parameter["PHP_INI"]}
sed -i 's/short_open_tag = Off/short_open_tag = On/' ${parameter["PHP_INI"]}
sed -i 's/;max_input_vars =.*/max_input_vars = 50000/' ${parameter["PHP_INI"]}
sed -i 's/session.gc_maxlifetime = 1440/session.gc_maxlifetime = 28800/' ${parameter["PHP_INI"]}
sed -i 's/mysql.allow_persistent = On/mysql.allow_persistent = Off/' ${parameter["PHP_INI"]}
sed -i 's/mysqli.allow_persistent = On/mysqli.allow_persistent = Off/' ${parameter["PHP_INI"]}
sed -i 's/pm = dynamic/pm = ondemand/' ${parameter["PHP_FPM_POOL"]}
sed -i 's/;pm.max_requests = 500/pm.max_requests = 10000/' ${parameter["PHP_FPM_POOL"]}
sed -i 's/^\(pm.max_children = \)[0-9]*/\1100/' ${parameter["PHP_FPM_POOL"]}

sed -i "s/\[www\]/\[${parameter["BRAND"]}\]/" ${parameter["PHP_FPM_POOL"]}
sed -i "s/^user =.*/user = ${parameter["PHP_USER"]}/" ${parameter["PHP_FPM_POOL"]}
sed -i "s/^group =.*/group = ${parameter["PHP_USER"]}/" ${parameter["PHP_FPM_POOL"]}
sed -ri "s/;?listen.owner =.*/listen.owner = ${parameter["PHP_USER"]}/" ${parameter["PHP_FPM_POOL"]}
sed -ri "s/;?listen.group =.*/listen.group = nginx/" ${parameter["PHP_FPM_POOL"]}
sed -ri "s/;?listen.mode = 0660/listen.mode = 0660/" ${parameter["PHP_FPM_POOL"]}
sed -ri "s/;?listen.allowed_clients =.*/listen.allowed_clients = 127.0.0.1/" ${parameter["PHP_FPM_POOL"]}
sed -i '/sendmail_path/,$d' ${parameter["PHP_FPM_POOL"]}
sed -i '/PHPSESSID/d' ${parameter["PHP_INI"]}
sed -i "s,.*date.timezone.*,date.timezone = ${parameter["TIMEZONE"]}," ${parameter["PHP_INI"]}

cat >> ${parameter["PHP_FPM_POOL"]} <<END
;;
;; Custom pool settings
php_flag[display_errors] = off
php_admin_flag[log_errors] = on
php_admin_value[error_log] = "${parameter["WEB_ROOT_PATH"]}/var/log/php-fpm-error.log"
php_admin_value[default_charset] = UTF-8
php_admin_value[memory_limit] = 1048M
php_admin_value[date.timezone] = ${parameter["TIMEZONE"]}
END

if [ "${parameter["FASTLY"]}" == "disabled" ] && [ "${_INSTANCE_NAME}" != "admin" ]; then

apt-get -qqy install varnish

cd /etc/varnish

git init
git remote add origin ${parameter["CODECOMMIT_SERVICES_REPO"]}
git fetch
git reset --hard origin/varnish
git checkout -t origin/varnish

cp varnish.service /etc/systemd/system/

fi

cd /etc/nginx
git init
git remote add origin ${parameter["CODECOMMIT_SERVICES_REPO"]}
git fetch
git reset --hard origin/nginx_${_INSTANCE_NAME}
git checkout -t origin/nginx_${_INSTANCE_NAME}

if [ "${_INSTANCE_NAME}" == "admin" ]; then
debconf-set-selections <<< "phpmyadmin phpmyadmin/internal/skip-preseed boolean true"
debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect"
debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean false"

apt-get -qqy install composer mariadb-client phpmyadmin
 
cp /usr/share/phpmyadmin/config.sample.inc.php /etc/phpmyadmin/config.inc.php
sed -i "s/.*blowfish_secret.*/\$cfg['blowfish_secret'] = '${parameter["BLOWFISH"]}';/" /etc/phpmyadmin/config.inc.php
sed -i "s/localhost/${parameter["DATABASE_ENDPOINT"]}/" /etc/phpmyadmin/config.inc.php
sed -i "s/PHPMYADMIN_PLACEHOLDER/${parameter["MYSQL_PATH"]}/g" /etc/nginx/conf.d/phpmyadmin.conf
sed -i "s,#include conf.d/phpmyadmin.conf;,include conf.d/phpmyadmin.conf;," /etc/nginx/sites-available/magento.conf
 
cat > /etc/logrotate.d/magento <<END
${parameter["WEB_ROOT_PATH"]}/var/log/*.log
{
su ${parameter["BRAND"]} ${parameter["PHP_USER"]}
create 660 ${parameter["BRAND"]} ${parameter["PHP_USER"]}
daily
rotate 7
notifempty
missingok
compress
}
END
fi

mkdir -p /etc/nginx/sites-enabled
ln -s /etc/nginx/sites-available/magento.conf /etc/nginx/sites-enabled/magento.conf
 
sed -i "s,VPC_CIDR,${parameter["VPC_CIDR"]}," /etc/nginx/nginx.conf
sed -i "s/HEALTH_CHECK_LOCATION/${parameter["HEALTH_CHECK_LOCATION"]}/" /etc/nginx/sites-available/magento.conf
sed -i "s,/var/www/html,${parameter["WEB_ROOT_PATH"]},g" /etc/nginx/conf.d/maps.conf
sed -i "s/PROFILER_PLACEHOLDER/${parameter["PROFILER"]}/" /etc/nginx/conf.d/maps.conf
echo '' > /etc/nginx/conf.d/default.conf
 
sed -i "s/example.com/${parameter["DOMAIN"]}/g" /etc/nginx/sites-available/magento.conf
sed -i "s/example.com/${parameter["DOMAIN"]}/g" /etc/nginx/nginx.conf
 
timedatectl set-timezone ${parameter["TIMEZONE"]}
 
cd /tmp

wget https://s3.${parameter["AWS_DEFAULT_REGION"]}.amazonaws.com/amazoncloudwatch-agent-${parameter["AWS_DEFAULT_REGION"]}/ubuntu/arm64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:amazon-cloudwatch-agent-${_INSTANCE_NAME}.json

chmod 750 /usr/bin/aws /root/aws
apt-get clean


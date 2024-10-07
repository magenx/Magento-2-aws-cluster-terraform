#!/bin/bash

. /tmp/build_header.sh

###################################################################################
###                               MARIADB CONFIGURATION                         ###
###################################################################################

if [ "${INSTANCE_NAME}" == "mariadb" ]; then
# ATTACH VOLUME
. /usr/local/bin/metadata
aws ec2 attach-volume --volume-id ${MARIADB_DATA_VOLUME} --instance-id ${INSTANCE_ID} --device /dev/xvdb
aws ec2 wait volume-in-use --volume-ids ${MARIADB_DATA_VOLUME}
sleep 5
FSTYPE=$(blkid -o value -s TYPE /dev/xvdb)
if [ -z "${FSTYPE}" ] || [ "${FSTYPE}" != "ext4" ]; then
mkfs.ext4 /dev/xvdb
fi
while [ ! -e /dev/xvdb ]; do sleep 1; done && mkdir -p /var/lib/mysql && mount /dev/xvdb /var/lib/mysql
UUID=$(blkid -s UUID -o value /dev/xvdb)
if [ -z "$UUID" ]; then
    echo "UUID is empty. ERROR."
    exit 1
fi
echo "UUID=${UUID} /var/lib/mysql ext4 defaults,nofail 0 2" >> /etc/fstab
# MARIADB INSTALLATION
curl -sS ${MARIADB_REPO_CONFIG} | bash -s -- --mariadb-server-version="mariadb-${MARIADB_VERSION}" --skip-maxscale --skip-verify --skip-eol-check
apt -qq update
apt -qq -y install mariadb-server bc libdbd-mariadb-perl git binutils pkg-config libssl-dev
systemctl enable mariadb
curl -sSo /etc/my.cnf https://raw.githubusercontent.com/magenx/magento-mysql/master/my.cnf/my.cnf
INNODB_BUFFER_POOL_SIZE=$(echo "0.90*$(awk '/MemTotal/ { print $2 / (1024*1024)}' /proc/meminfo | cut -d'.' -f1)" | bc | xargs printf "%1.0f")
if [ "${INNODB_BUFFER_POOL_SIZE}" == "0" ]; then INNODB_BUFFER_POOL_SIZE=1; fi
sed -i "s/innodb_buffer_pool_size = 4G/innodb_buffer_pool_size = ${INNODB_BUFFER_POOL_SIZE}G/" /etc/my.cnf
systemctl restart mariadb
sleep 5
mariadb --connect-expired-password  <<EOMYSQL
ALTER USER 'root'@'localhost' IDENTIFIED BY "${parameter["DATABASE_ROOT_PASSWORD"]}";
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
exit
EOMYSQL

cat > /root/.my.cnf <<END
[client]
user=root
password="${parameter["DATABASE_ROOT_PASSWORD"]}"
END

cat > /root/.mytop <<END
user=root
pass=${parameter["DATABASE_ROOT_PASSWORD"]}
db=mysql
END

chmod 600 /root/.my.cnf /root/.mytop

mariadb <<EOMYSQL
CREATE USER '${parameter["DATABASE_USER"]}'@'${parameter["CIDR"]/0.0\/16/%}' IDENTIFIED BY '${parameter["DATABASE_PASSWORD"]}';
CREATE DATABASE IF NOT EXISTS ${parameter["DATABASE_NAME"]};
GRANT ALL PRIVILEGES ON ${parameter["DATABASE_NAME"]}.* TO '${parameter["DATABASE_USER"]}'@'${parameter["CIDR"]/0.0\/16/%}' WITH GRANT OPTION;
exit
EOMYSQL

sed -i "s/bind-address = 127.0.0.1/bind-address = ${DATABASE_ENDPOINT}/" /etc/my.cnf

cat <<END > /etc/systemd/system/attach-ebs-volume.service
[Unit]
Description=Attach EBS Volume for MariaDB
Before=mariadb.service
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'aws ec2 attach-volume --volume-id ${MARIADB_DATA_VOLUME} --instance-id \${INSTANCE_ID} --device /dev/xvdb && while [ ! -e /dev/xvdb ]; do sleep 1; done && mount /dev/xvdb /var/lib/mysql'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
END

cat <<END > /etc/systemd/system/detach-ebs-volume.service
[Unit]
Description=Detach EBS volume on shutdown
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'aws ec2 detach-volume --volume-id ${MARIADB_DATA_VOLUME}'

[Install]
WantedBy=halt.target reboot.target shutdown.target
END

systemctl enable attach-ebs-volume.service
systemctl enable detach-ebs-volume.service

mkdir -p /backup
echo "${parameter["EFS_SYSTEM_ID"]}:/ /backup efs _netdev,noresvport,tls,iam,accesspoint=${parameter["EFS_ACCESS_POINT_BACKUP"]} 0 0" >> /etc/fstab

cat <<END > /etc/cron.daily/database_backup
#!/bin/bash

BACKUP_DIR="/backup
DATE=\$(date +"%d-%m-%Y")
TIMER=\$(date +"%H-%M-%S")

mkdir -p "\${BACKUP_DIR}/\${DATE}"
DATABASES=\$(mysql -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")
for DATABASE in \${DATABASES}; do
    FILE="\${BACKUP}/\${DATE}/mysql-\${DATABASE}-\${DATE}-\${TIMER}.sql.gz"
    mysqldump --single-transaction --routines --triggers --events --databases \${DATABASE} | gzip > "\${FILE}"
done
END

chmod +x /etc/cron.daily/database_backup

# BUILD EFS UTILS
cd /tmp
git clone https://github.com/aws/efs-utils
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
. "$HOME/.cargo/env"
cd efs-utils
./build-deb.sh
apt-get -y install ./build/amazon-efs-utils*deb
rm -rf ~/.cargo ~/.rustup

fi

###################################################################################

. /tmp/build_footer.sh

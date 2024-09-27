#!/bin/bash
#=================================================================================#
#        MagenX e-commerce stack for Magento 2                                    #
#        Copyright (C) 2013-present admin@magenx.com                              #
#        All rights reserved.                                                     #
#=================================================================================#
SELF=$(basename $0)
MAGENX_VERSION=$(curl -s https://api.github.com/repos/magenx/Magento-2-server-installation/tags 2>&1 | head -3 | grep -oP '(?<=")\d.*(?=")')
MAGENX_BASE="https://magenx.sh"

###################################################################################
###                              REPOSITORY AND PACKAGES                        ###
###################################################################################

# Github installation repository raw url
MAGENX_INSTALL_GITHUB_REPO="https://raw.githubusercontent.com/magenx/Magento-2-server-installation/master"

## Version lock
COMPOSER_VERSION="2.4"
RABBITMQ_VERSION="3.12*"
MARIADB_VERSION="10.11"
OPENSEARCH_VERSION="2.x"
VARNISH_VERSION="75"
REDIS_VERSION="7"

# Repositories
MARIADB_REPO_CONFIG="https://downloads.mariadb.com/MariaDB/mariadb_repo_setup"

# Nginx configuration
NGINX_VERSION=$(curl -s http://nginx.org/en/download.html | grep -oP '(?<=gz">nginx-).*?(?=</a>)' | head -1)
MAGENX_NGINX_GITHUB_REPO="https://raw.githubusercontent.com/magenx/Magento-nginx-config/master/"
MAGENX_NGINX_GITHUB_REPO_API="https://api.github.com/repos/magenx/Magento-nginx-config/contents/magento2"

# WebStack Packages .deb
WEB_STACK_CHECK="mysql* rabbitmq* elasticsearch opensearch percona-server* maria* php* nginx* ufw varnish* certbot* redis* webmin"

###################################################################################
###                                    CLEANUP                                  ###
###################################################################################
## Debian

# check if web stack is clean and clean it
installed_packages="$(apt -qq list --installed ${WEB_STACK_CHECK} 2> /dev/null | cut -d'/' -f1 | tr '\n' ' ')"
if [ ! -z "$installed_packages" ]; then
apt -qq -y remove --purge "${installed_packages}"
fi

###################################################################################
###                                LINUX UPDATE                                 ###
###################################################################################

# stack update
apt -qqy update
apt -qqy install jq apt-transport-https lsb-release ca-certificates curl gnupg software-properties-common snmp syslog-ng

###################################################################################
###                               GET PARAMETERSTORE                            ###
###################################################################################

PARAMETER=$(aws ssm get-parameter --name "${AWS_ENVIRONMENT}" --query 'Parameter.Value' --output text)
declare -A parameter
while IFS== read -r key value; do parameter["$key"]="$value"; done < <(echo ${PARAMETER} | jq -r 'to_entries[] | .key + "=" + .value')

###################################################################################
###                           SET PRIVATE ROUTE53 HOSTNAMES                     ###
###################################################################################

OPENSEARCH_ENDPOINT="opensearch.${parameter["BRAND"]}.internal"
REDIS_ENDPOINT="redis.${parameter["BRAND"]}.internal"
RABBITMQ_ENDPOINT="rabbitmq.${parameter["BRAND"]}.internal"
DATABASE_ENDPOINT="mariadb.${parameter["BRAND"]}.internal"

###################################################################################
###                             GET INSTANCE METADATA                           ###
###################################################################################

cat <<END > /usr/local/bin/metadata
#!/bin/bash
# Fetch metadata
AWSTOKEN=\$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 600")
INSTANCE_ID=\$(curl -s -H "X-aws-ec2-metadata-token: \${AWSTOKEN}" http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_HOSTNAME=\$(curl -s -H "X-aws-ec2-metadata-token: \${AWSTOKEN}" http://169.254.169.254/latest/meta-data/tags/instance/Hostname)
INSTANCE_TYPE=\$(curl -s -H "X-aws-ec2-metadata-token: \${AWSTOKEN}" http://169.254.169.254/latest/meta-data/instance-type)
INSTANCE_IP=\$(curl -s -H "X-aws-ec2-metadata-token: \${AWSTOKEN}" http://169.254.169.254/latest/meta-data/local-ipv4)

# Export variables
export INSTANCE_ID="\${INSTANCE_ID}"
export INSTANCE_HOSTNAME="\${INSTANCE_HOSTNAME}"
export INSTANCE_TYPE="\${INSTANCE_TYPE}"
export INSTANCE_IP="\${INSTANCE_IP}"
END
chmod +x /usr/local/bin/metadata
. /usr/local/bin/metadata

###################################################################################
###                                   SET TIMEZONE                              ###
###################################################################################

# configure system/magento timezone
ln -fs /usr/share/zoneinfo/${parameter["TIMEZONE"]} /etc/localtime
dpkg-reconfigure --frontend noninteractive tzdata

###################################################################################
###                               CLOUDMAP CONFIGURATION                        ###
###################################################################################

cat <<END > /usr/local/bin/cloudmap-register
#! /bin/bash
. /usr/local/bin/metadata
if ! grep -q "${INSTANCE_IP}  ${INSTANCE_HOSTNAME}" /etc/hosts; then
  echo "${INSTANCE_IP}  ${INSTANCE_HOSTNAME}" >> /etc/hosts
fi
hostnamectl set-hostname ${INSTANCE_HOSTNAME}
aws servicediscovery register-instance \
  --region ${parameter["AWS_DEFAULT_REGION"]} \
  --service-id ${SERVICE_ID} \
  --instance-id \${INSTANCE_ID} \
  --attributes AWS_INSTANCE_IPV4=\${INSTANCE_IP}
END

cat <<END > /usr/local/bin/cloudmap-deregister
#! /bin/bash
. /usr/local/bin/metadata
aws servicediscovery deregister-instance \
  --region ${parameter["AWS_DEFAULT_REGION"]} \
  --service-id ${SERVICE_ID} \
  --instance-id \${INSTANCE_ID}
END

cat <<END > /etc/systemd/system/cloudmap.service
[Unit]
Description=Run AWS CloudMap service
Requires=network-online.target
After=network-online.target

[Service]
Type=oneshot
KillMode=process
RemainAfterExit=yes

ExecStart=/usr/local/bin/cloudmap-register
ExecStop=/usr/local/bin/cloudmap-deregister

[Install]
WantedBy=multi-user.target
END

systemctl enable cloudmap.service

###################################################################################
###                            AWS SERVICES CONFIGURATION                       ###
###################################################################################

wget https://s3.${parameter["AWS_DEFAULT_REGION"]}.amazonaws.com/amazon-ssm-${parameter["AWS_DEFAULT_REGION"]}/latest/debian_arm64/amazon-ssm-agent.deb
dpkg -i amazon-ssm-agent.deb
systemctl enable amazon-ssm-agent

wget https://s3.${parameter["AWS_DEFAULT_REGION"]}.amazonaws.com/amazoncloudwatch-agent-${parameter["AWS_DEFAULT_REGION"]}/ubuntu/arm64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:amazon-cloudwatch-agent-${INSTANCE_NAME}.json


#!/bin/bash
#=================================================================================#
#        MagenX e-commerce stack for Magento 2                                    #
#        Copyright (C) 2013-present admin@magenx.com                              #
#        All rights reserved.                                                     #
#=================================================================================#
SELF=$(basename $0)

###################################################################################
###                                    CLEANUP                                  ###
###################################################################################
## Debian
# WebStack Packages .deb
WEB_STACK_CHECK="mysql* rabbitmq* elasticsearch opensearch percona-server* maria* php* nginx* ufw varnish* certbot* redis* webmin"

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

export FRONTEND_ENDPOINT="frontend.${parameter["BRAND"]}.internal"
export ADMIN_ENDPOINT="admin.${parameter["BRAND"]}.internal"
export VARNISH_ENDPOINT="varnish.${parameter["BRAND"]}.internal"
export OPENSEARCH_ENDPOINT="opensearch.${parameter["BRAND"]}.internal"
export REDIS_ENDPOINT="redis.${parameter["BRAND"]}.internal"
export RABBITMQ_ENDPOINT="rabbitmq.${parameter["BRAND"]}.internal"
export DATABASE_ENDPOINT="mariadb.${parameter["BRAND"]}.internal"

###################################################################################
###                             GET INSTANCE METADATA                           ###
###################################################################################

cat <<END > /usr/local/bin/metadata
#!/bin/bash
# Fetch metadata
AWSTOKEN=\$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 600")
REGION=\$(curl -s -H "X-aws-ec2-metadata-token: \${AWSTOKEN}" http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_ID=\$(curl -s -H "X-aws-ec2-metadata-token: \${AWSTOKEN}" http://169.254.169.254/latest/meta-data/instance-id)
INSTANCE_HOSTNAME=\$(curl -s -H "X-aws-ec2-metadata-token: \${AWSTOKEN}" http://169.254.169.254/latest/meta-data/tags/instance/Hostname)
INSTANCE_NAME=\$(curl -s -H "X-aws-ec2-metadata-token: \${AWSTOKEN}" http://169.254.169.254/latest/meta-data/tags/instance/Instance_Name)
CLOUDMAP_SERVICE_ID=\$(curl -s -H "X-aws-ec2-metadata-token: \${AWSTOKEN}" http://169.254.169.254/latest/meta-data/tags/instance/Cloudmap_Service_Id)
INSTANCE_TYPE=\$(curl -s -H "X-aws-ec2-metadata-token: \${AWSTOKEN}" http://169.254.169.254/latest/meta-data/instance-type)
INSTANCE_IP=\$(curl -s -H "X-aws-ec2-metadata-token: \${AWSTOKEN}" http://169.254.169.254/latest/meta-data/local-ipv4)

# Export variables
export REGION="\${REGION}"
export INSTANCE_ID="\${INSTANCE_ID}"
export INSTANCE_HOSTNAME="\${INSTANCE_HOSTNAME}"
export INSTANCE_NAME="\${INSTANCE_NAME}"
export CLOUDMAP_SERVICE_ID="\${CLOUDMAP_SERVICE_ID}"
export INSTANCE_TYPE="\${INSTANCE_TYPE}"
export INSTANCE_IP="\${INSTANCE_IP}"
END
chmod +x /usr/local/bin/metadata

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
#!/bin/bash
. /usr/local/bin/metadata
if ! grep -q "\${INSTANCE_IP}  \${INSTANCE_HOSTNAME}" /etc/hosts; then
  echo "\${INSTANCE_IP}  \${INSTANCE_HOSTNAME}" >> /etc/hosts
fi
hostnamectl set-hostname \${INSTANCE_HOSTNAME}
aws servicediscovery register-instance \
  --region \${REGION"} \
  --service-id \${CLOUDMAP_SERVICE_ID} \
  --instance-id \${INSTANCE_ID} \
  --attributes AWS_INSTANCE_IPV4=\${INSTANCE_IP}
END

cat <<END > /usr/local/bin/cloudmap-deregister
#!/bin/bash
. /usr/local/bin/metadata
aws servicediscovery deregister-instance \
  --region \${REGION} \
  --service-id \${CLOUDMAP_SERVICE_ID} \
  --instance-id \${INSTANCE_ID}
END

cat <<END > /etc/systemd/system/cloudmap-register.service
[Unit]
Description=Register AWS CloudMap service on boot
Requires=network-online.target
After=network-online.target

[Service]
Type=oneshot
KillMode=process
RemainAfterExit=yes

ExecStart=/usr/local/bin/cloudmap-register

[Install]
WantedBy=multi-user.target
END

cat <<END > /etc/systemd/system/cloudmap-deregister.service
[Unit]
Description=Deregister AWS CloudMap service on shutdown
Requires=network-online.target

DefaultDependencies=no
Before=shutdown.target reboot.target halt.target hibernate.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/cloudmap-deregister
RemainAfterExit=no

[Install]
WantedBy=halt.target reboot.target shutdown.target hibernate.target
END

systemctl enable cloudmap-deregister.service cloudmap-register.service

###################################################################################
###                            AWS SERVICES CONFIGURATION                       ###
###################################################################################

wget https://s3.${REGION}.amazonaws.com/amazon-ssm-${REGION}/latest/debian_arm64/amazon-ssm-agent.deb
dpkg -i amazon-ssm-agent.deb
systemctl enable amazon-ssm-agent

wget https://s3.${REGION}.amazonaws.com/amazoncloudwatch-agent-${REGION}/ubuntu/arm64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:amazon-cloudwatch-agent-\${INSTANCE_NAME}.json


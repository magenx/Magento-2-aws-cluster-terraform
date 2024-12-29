#!/bin/bash
#=================================================================================#
#        MagenX e-commerce stack for Magento 2                                    #
#        Copyright (C) 2013-present admin@magenx.com                              #
#        All rights reserved.                                                     #
#=================================================================================#

# check if web stack is clean and clean it
WEB_STACK_CHECK="mysql* rabbitmq* elasticsearch opensearch percona-server* maria* php* nginx* apache* ufw varnish* certbot* redis* webmin awscli"
INSTALLED_PACKAGES="$(apt -qq list --installed $${WEB_STACK_CHECK} 2> /dev/null | cut -d'/' -f1 | tr '\n' ' ')"
if [ ! -z "$${INSTALLED_PACKAGES}" ]; then
apt -qq -y remove --purge "$${INSTALLED_PACKAGES}"
fi

# stack update
apt -qqy update
apt -qqy install jq apt-transport-https lsb-release ca-certificates curl gnupg software-properties-common snmp syslog-ng-core snapd
echo "export PATH=\$PATH:/snap/bin" >> ~/.bashrc
source ~/.bashrc
snap install amazon-ssm-agent --classic
snap install aws-cli --classic

# Parameter store query script
cat <<END > /usr/local/bin/parameterstore
#!/bin/bash
parameterstore() {
    local key=$1
    aws ssm get-parameter --name "${AWS_ENVIRONMENT}" --query 'Parameter.Value' --output text | jq -r ".$${key}"
}
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <parameter-key>"
    echo "Example: $0 BRAND"
    exit 1
fi
key=$1
parameterstore "$${key}"
END
chmod +x /usr/local/bin/parameterstore

# Create local setup directories
LOG_DIRECTORY="/opt/${BRAND}/setup/log"
HASH_DIRECTORY="/opt/${BRAND}/setup/.hash"
INIT_DIRECTORY="/opt/${BRAND}/setup/instance"
INSTANCE_DIRECTORY="/opt/${BRAND}/setup/${INSTANCE_NAME}"
mkdir -p "$${LOG_DIRECTORY}"
mkdir -p "$${HASH_DIRECTORY}"
mkdir -p "$${INIT_DIRECTORY}"
mkdir -p "$${INSTANCE_DIRECTORY}"
touch /opt/${BRAND}/init

# Download configuration files from s3
OPTIONS="--quiet --exact-timestamps --delete --checksum-mode ENABLED --checksum-algorithm SHA256"
aws s3 sync "s3://${S3_SYSTEM_BUCKET}/setup/instance" "$${INIT_DIRECTORY}" $${OPTIONS} && \
aws s3 sync "s3://${S3_SYSTEM_BUCKET}/setup/${INSTANCE_NAME}" "$${INSTANCE_DIRECTORY}" $${OPTIONS}

# Check if both sync commands were successful
if [ $? -eq 0 ]; then
    # Execute scripts in order from INIT_DIRECTORY
    for SCRIPT in $(ls "$${INIT_DIRECTORY}"/*.sh | sort); do
        LOG_FILE="$${LOG_DIRECTORY}/$(basename "$${SCRIPT}").log"
        HASH_FILE="$${HASH_DIRECTORY}/$(basename "$${SCRIPT}").md5sum"
        NEW_HASH=$(md5sum "$${SCRIPT}" | awk '{print $1}')        
        if [ ! -f "$${HASH_FILE}" ] || [ "$${NEW_HASH}" != "$(cat "$${HASH_FILE}")" ]; then
            echo "$${NEW_HASH}" > "$${HASH_FILE}"
            echo -e "\n$(date) Running: $${SCRIPT}" | tee -a "$${LOG_FILE}"
            bash "$${SCRIPT}" >>"$${LOG_FILE}" 2>&1
        fi
    done
    # Execute scripts in order from INSTANCE_DIRECTORY
    for SCRIPT in $(ls "$${INSTANCE_DIRECTORY}"/*.sh | sort); do
        LOG_FILE="$${LOG_DIRECTORY}/$(basename "$${SCRIPT}").log"
        HASH_FILE="$${HASH_DIRECTORY}/$(basename "$${SCRIPT}").md5sum"
        NEW_HASH=$(md5sum "$${SCRIPT}" | awk '{print $1}')        
        if [ ! -f "$${HASH_FILE}" ] || [ "$${NEW_HASH}" != "$(cat "$${HASH_FILE}")" ]; then
            echo "$${NEW_HASH}" > "$${HASH_FILE}"
            echo -e "\n$(date) Running: $${SCRIPT}" | tee -a "$${LOG_FILE}"
            bash "$${SCRIPT}" >>"$${LOG_FILE}" 2>&1
        fi
    done
else
    echo "Error syncing files from S3"
fi

cd /tmp
wget https://amazoncloudwatch-agent.s3.amazonaws.com/debian/arm64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:amazon-cloudwatch-agent-${INSTANCE_NAME}.json

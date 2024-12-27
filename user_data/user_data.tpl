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
snap install amazon-ssm-agent --classic
snap install aws-cli --classic

# Parameter store query script
cat <<END > /usr/local/bin/parameterstore
#!/bin/bash
PARAMETER=$(aws ssm get-parameter --name "${AWS_ENVIRONMENT}" --query 'Parameter.Value' --output text)
declare -A parameter
while IFS== read -r key value; do parameter["$${key}"]="$${value}"; done < <(echo $${PARAMETER} | jq -r 'to_entries[] | .key + "=" + .value')
END
chmod +x /usr/local/bin/parameterstore

# Create local setup directories
INIT_DIRECTORY="/opt/${BRAND}/instance"
INSTANCE_DIRECTORY="/opt/${BRAND}/${INSTANCE_NAME}"
mkdir -p "$${INIT_DIRECTORY}/{.hash,log}"
mkdir -p "$${INSTANCE_DIRECTORY}/{.hash,log}"
touch $${INIT_DIRECTORY}/init

# Download configuration files from s3
OPTIONS="--quiet --exact-timestamps --checksum-mode=ENABLED --checksum-algorithm=SHA256"
aws s3 sync $${OPTIONS} "s3://${S3_SYSTEM_BUCKET}/setup/instance/" "$${INIT_DIRECTORY}/" && \
aws s3 sync $${OPTIONS} "s3://${S3_SYSTEM_BUCKET}/setup/${INSTANCE_NAME}/" "$${INSTANCE_DIRECTORY}/"

# Check if both sync commands were successful
if [ $? -eq 0 ]; then
    # Execute scripts in order from INIT_DIRECTORY
    for SCRIPT in $(ls "$${INIT_DIRECTORY}"/*.sh | sort); do
        LOG_FILE="$${INIT_DIRECTORY}/log/$(basename "$${SCRIPT}").log"
        HASH_DIR="$${INIT_DIRECTORY}/.hash"
        HASH_FILE="$${HASH_DIR}/$(basename "$${SCRIPT}").md5sum"
        NEW_HASH=$(md5sum "$${SCRIPT}" | awk '{print $1}')        
        if [ ! -f "$${HASH_FILE}" ] || [ "$${NEW_HASH}" != "$(cat "$${HASH_FILE}")" ]; then
            echo "$${NEW_HASH}" > "$${HASH_FILE}"
            echo -e "\n$(date) Running: $${SCRIPT}" | tee -a "$${LOG_FILE}"
            bash "$${SCRIPT}" >>"$${LOG_FILE}" 2>&1
        fi
    done
    # Execute scripts in order from INSTANCE_DIRECTORY
    for SCRIPT in $(ls "$${INSTANCE_DIRECTORY}"/*.sh | sort); do
        LOG_FILE="$${INSTANCE_DIRECTORY}/log/$(basename "$${SCRIPT}").log"
        HASH_DIR="$${INSTANCE_DIRECTORY}/.hash"
        HASH_FILE="$${HASH_DIR}/$(basename "$${SCRIPT}").md5sum"
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

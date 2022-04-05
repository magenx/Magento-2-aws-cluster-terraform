#!/bin/bash

## debug
if [ -z "${_PARAMETERSTORE_NAME}" ]; then
echo "Error: _PARAMETERSTORE_NAME is empty - build is broken"
exit 1
fi

_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
_INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)

## get environment variables from aws parameter store
_PARAMETER=$(aws ssm get-parameter --name "${_PARAMETERSTORE_NAME}" --query 'Parameter.Value' --output text)
declare -A parameter
while IFS== read -r key value; do parameter["$key"]="$value"; done < <(echo ${_PARAMETER} | jq -r 'to_entries[] | .key + "=" + .value')

## basic check for installed packages
_LINUX_PACKAGES="nginx php${parameter["PHP_VERSION"]} ${parameter["LINUX_PACKAGES"]}"
for _LINUX_PACKAGE in ${_LINUX_PACKAGES}; do
  _STATUS="$(dpkg-query -W --showformat='${db:Status-Status}' "${_LINUX_PACKAGE}" 2>&1)"
  if [ ! "${_STATUS}" = "installed" ]; then
    echo "Error: ${_LINUX_PACKAGE} not installed - build is broken"
    exit 1
  fi
done

## test for EFS mount
if [ $(stat -f -L -c %T ${parameter["WEB_ROOT_PATH"]}/pub/media) != "nfs" ]; then
echo "Error: EFS remote storage not mounted - build is broken"
mount -a
grep nfs /var/log/syslog
df -h
cat /etc/fstab
exit 1
fi

## create report also send to sns channel
cat > /tmp/imagebuild_test <<END
Instance: ${_INSTANCE_NAME} ${_INSTANCE_ID} ${_INSTANCE_TYPE}
Region: ${parameter["AWS_DEFAULT_REGION"]}
Brand: ${parameter["BRAND"]}
Uptime since:  $(uptime -s)
 
END

curl ifconfig.io/all >> /tmp/imagebuild_test
echo "-------------------------------------------------------" >> /tmp/imagebuild_test
df -h >> /tmp/imagebuild_test
echo "-------------------------------------------------------" >> /tmp/imagebuild_test
dpkg-query -l nginx php${parameter["PHP_VERSION"]} ${parameter["LINUX_PACKAGES"]} >> /tmp/imagebuild_test
echo "-------------------------------------------------------" >> /tmp/imagebuild_test
ss -tunlp >> /tmp/imagebuild_test

aws sns publish \
--region ${parameter["AWS_DEFAULT_REGION"]} \
--topic-arn ${parameter["SNS_TOPIC_ARN"]} \
--subject "ImageBuilder test: ${parameter["BRAND"]} at ${parameter["AWS_DEFAULT_REGION"]} ${_INSTANCE_NAME} ${_INSTANCE_ID}" \
--message file:///tmp/imagebuild_test


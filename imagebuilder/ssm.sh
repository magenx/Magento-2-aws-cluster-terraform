#!/bin/bash

AWS_DEFAULT_REGION="$(curl -s http://169.254.169.254/latest/meta-data/placement/region)"

wget https://s3.${AWS_DEFAULT_REGION}.amazonaws.com/amazon-ssm-${AWS_DEFAULT_REGION}/latest/debian_arm64/amazon-ssm-agent.deb
dpkg -i amazon-ssm-agent.deb
systemctl enable amazon-ssm-agent

touch perform_cleanup

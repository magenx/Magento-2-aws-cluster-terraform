#!/bin/bash

AWS_DEFAULT_REGION="$(curl -s http://169.254.169.254/latest/meta-data/placement/region)"

## install SSM agent to manage EC2 Instance and ImageBuilder AMI build
cd /tmp
wget https://s3.${AWS_DEFAULT_REGION}.amazonaws.com/amazon-ssm-${AWS_DEFAULT_REGION}/latest/debian_arm64/amazon-ssm-agent.deb
dpkg -i amazon-ssm-agent.deb
systemctl enable amazon-ssm-agent

## trigger system cleanup
touch perform_cleanup

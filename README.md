# Magento 2 AWS cluster with Terraform

## Classic configuration for Magento 2 auto scaling cluster on AWS :heart:
## Powered by Graviton2 Processor
## AWS CloudShell + Terraform

``` 
https://docs.aws.amazon.com/index.html
https://www.terraform.io/docs/
https://aws.amazon.com/cloudshell/
```
# Deployment into default VPC
- Login to AWS Console
- Start AWS CloudShell
- Install Terraform:
```
   sudo yum install -y yum-utils
   sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
   sudo yum -y install terraform
```
- Clone repo:
> 
```
$ git clone https://github.com/magenx/Magento-2-aws-cluster-terraform.git
```
> 
- Create ssl certificate in Certificate Manager
- For CloudFront to work: The certificate must be also imported in the US East (N. Virginia) Region.
- Check all details / all files / adjust your settings
- Run:
```
   terraform init
   terraform apply
```

## Complete setup:
- [x] `5` autoscaling groups with launch templates converted from `user_data`
- [x] `4` load balancer target groups (varnish frontend admin staging)
- [x] `1` build server
- [x] `2` load balancers (external/internal) with listeners / rules
- [x] `1` rds mysql database
- [x] `1` elk domain
- [x] `2` redis elasticache cluster for sessions and cache
- [x] `1` rabbitmq broker to manage Magento queue messages
- [x] `2` s3 buckets for [media] images and [system] files and logs (with access policy)
- [x] `1` single codecommit repository with 3 branches (main build staging)
- [x] `1` cloudfront s3 origin distribution
- [x] `1` efs file system for shared folders, with mount target per AZ
- [x] `1` sns topic default subscription email alerts
- [x] Autoscaling policy per each group, excluding `build` instance
- [x] Managed with Systems Manager [https://aws.amazon.com/systems-manager/] agent installed
- [x] Create ssm documents and EventBridge rules to run commands remotely 
- [x] CloudWatch agent configured to stream logs
- [x] All Magento files managed with git only
- [x] Live shop in production mode / read-only 
- [x] Security groups configured for every service and instances
- [x] WAF basic rules

## Magento 2 development | source code:
- Terraform creates CodeCommit repository
- Local provisioner mirror files from Github - https://github.com/magenx/Magento-2 - to CodeCommit.
- EC2 instance user_data on boot clone files from CodeCommit branch.
- Magento 2 minimal package ready for installation.
- Run SSM Document to install Magento

## CI/CD scenario:
- Event driven
- Changes in CodeCommit repository triggers EventsBridge rule.
- SSM Document pull from CodeCommit repository and cleanup.
- Change deployment logic to your needs.

## Infrastructure DevOps and beyond:
- Terraform [https://www.terraform.io/docs/]
- Get state => migrate => edit => share

## TODO:
- WAF Rules
- Staging database/redis/elk configuration
- Proper vars

> enjoy catching bugs
##### example below setup configured:
![Magento_2_AWS_cloud_auto_scaling_magenx-big](https://user-images.githubusercontent.com/1591200/106358223-ac7eaf00-6302-11eb-963e-cc0d0136d88f.png)

<sub>[Magento 2 on the AWS Cloud: Quick Start Deployment](https://www.magenx.com/blog/post/adobe-commerce-cloud-alternative-infrastructure-as-code-terraform-configuration.html)</sub>

# Magento 2 AWS cluster with Terraform
[!] `Rolling Release` `WIP` `POC` `SandBox` `PlayGround` `R&D` `DevOps`

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
- [x] `4` autoscaling groups with launch templates base64 converted from user_data.*
- [x] `4` instances target groups (varnish frontend admin staging)
- [x] `2` load balancers (external/internal) with listeners / rules / security groups
- [x] `1` rds mysql database
- [x] `1` build server
- [x] `1` elk domain
- [x] `2` redis elasticache cluster
- [x] `1` rabbitmq broker
- [x] `2` s3 buckets for [media] and [system] files and logs
- [x] `1` codecommit repository 4 branches (main build staging)
- [x] `1` cloudfront s3 origin distribution
- [x] `1` efs file system for shared folders
- [x] `1` sns topic and email subscription alerts for asg
- [x] Autoscaling policy per group
- [x] Managed with Systems Manager [https://aws.amazon.com/systems-manager/]
- [x] CloudWatch + EventsBridge metrics / logs / alarms / events / triggers
- [x] All Magento files managed with git only
- [x] Live shop in production mode / read-only 
- [x] WAF basic rules

## Magento 2 development | source code:
- Terraform creates CodeCommit repository
- Local provisioner mirror files from Github - https://github.com/magenx/Magento-2 - to CodeCommit.
- EC2 instance user_data on boot clone files from CodeCommit.
- Magento 2 minimal package ready for installation.
- Run SSM Document to install Magento

## CI/CD scenario:
- Event driven
- Changes in CodeCommit repository triggers EventsBridge rule.
- System Manager runs bash script and cleanup on success.
- Checking environment and pull from CodeCommit repository and cleanup.
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

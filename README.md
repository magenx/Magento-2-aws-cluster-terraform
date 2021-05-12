## Magento 2 | [Auto Scaling](https://aws.amazon.com/autoscaling/) cluster with Terraform on AWS cloud :heart:
> deploy a full-scale e-commerce infrastructure based on Magento 2 in a matter of seconds

<img src="https://user-images.githubusercontent.com/1591200/117845471-7abda280-b278-11eb-8c88-db3fa307ae40.jpeg" width="210" height="150"><img src="https://user-images.githubusercontent.com/1591200/117845982-edc71900-b278-11eb-81ec-e19465f1344c.jpeg" width="200" height="150"><img src="https://user-images.githubusercontent.com/1591200/117846734-9c6b5980-b279-11eb-83b2-27171448bb42.png" width="215" height="150">

<br />

## AWS Graviton2 Processor - Enabling the best performance in Amazon EC2:
![aws-graviton2](https://user-images.githubusercontent.com/1591200/117844857-f0753e80-b277-11eb-9d27-fe8eacdf6c19.png)

<br />

## Developer documentation to read:
``` 
https://devdocs.magento.com/
https://docs.aws.amazon.com/index.html
https://www.terraform.io/docs/
https://aws.amazon.com/cloudshell/
```
<br />

# Deployment into default VPC:
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
- [x] `4` target groups for load balancer (varnish frontend admin staging)
- [x] `1` build server to compile all the code
- [x] `2` load balancers (external/internal) with listeners / rules
- [x] `1` rds mysql database
- [x] `1` elk elasticsearch domain for Magento catalog search
- [x] `2` redis elasticache cluster for sessions and cache
- [x] `1` rabbitmq broker to manage Magento queue messages
- [x] `2` s3 buckets for [media] images and [system] files and logs (with access policy)
- [x] `1` single codecommit repository with 3 branches (main build staging)
- [x] `1` cloudfront s3 origin distribution
- [x] `1` efs file system for shared folders, with mount target per AZ
- [x] `1` sns topic default subscription to receive email alerts
##
- [x] Autoscaling policy per each group, excluding `build` instance
- [x] Managed with Systems Manager [https://aws.amazon.com/systems-manager/] agent installed
- [x] Instance Profile assigned to simplified EC2 management
- [x] Create ssm documents and EventBridge rules to run commands remotely 
- [x] CloudWatch agent configured to stream logs
- [x] All Magento files managed with git only
- [x] Live shop in production mode / read-only 
- [x] Security groups configured for every service and instances
- [x] WAF basic rules

## Magento 2 development | source code:
- [Terraform](https://www.terraform.io/docs/) creates CodeCommit repository
- Local provisioner copy files from Github to CodeCommit - https://github.com/magenx/Magento-2 - aws branch.
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
- edit => migrate => share

## TODO:
- WAF Rules
- Staging database/redis/elk configuration
- Proper vars

##
![Magento_2_AWS_cloud_auto_scaling_magenx-big](https://user-images.githubusercontent.com/1591200/106358223-ac7eaf00-6302-11eb-963e-cc0d0136d88f.png)

<sub>[Magento 2 on the AWS Cloud: Quick Start Deployment](https://www.magenx.com/blog/post/adobe-commerce-cloud-alternative-infrastructure-as-code-terraform-configuration.html)</sub>

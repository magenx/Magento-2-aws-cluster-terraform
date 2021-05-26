## Magento 2 [auto scaling](https://aws.amazon.com/autoscaling/) cluster with Terraform on AWS cloud :heart:
> deploy a full-scale e-commerce infrastructure based on Magento 2 in a matter of seconds

<img src="https://user-images.githubusercontent.com/1591200/117845471-7abda280-b278-11eb-8c88-db3fa307ae40.jpeg" width="210" height="140"> <img src="https://user-images.githubusercontent.com/1591200/117845982-edc71900-b278-11eb-81ec-e19465f1344c.jpeg" width="180" height="145"> <img src="https://user-images.githubusercontent.com/1591200/118028531-158ead80-b35b-11eb-8957-636de16ada34.png" width="250" height="155">

<br />

## AWS Graviton2 Processor - Enabling the best performance in EC2:
![aws-graviton2](https://user-images.githubusercontent.com/1591200/117844857-f0753e80-b277-11eb-9d27-fe8eacdf6c19.png)

<br />

## [?] Why we need Adobe Commerce Cloud alternative:
The biggest issue is that ACC pricing based on GMV % and AOV %, with this approach, you invest money in the development of a third-party business, but not your own.
Why spend so much money without having control over your business in the cloud?
Configuring your own infrastructure these days is the most profitable way. You manage the resources, you have a complete overview how it works and you have full control over the money invested in your own infrastructure. At any time you can make changes to both infrastructure and application design without thinking about restrictions, 3rd party platform limitations and unforeseen costs. There are no hidden bills and payments for excess resources, which, as a result, you will not need.  

Adobe Commerce Cloud has lots of technical problems due to the fact that many services compete on the same server and share the processor time, memory, network and I/O.  
Bad architectural solution using monolitic servers, not cloud native solution, that was not made specifically for Magento, but adapted in rush using many wrappers, with manual pseudo scaling and 48 hours to 5 days to accept and deploy new settings.

```
Obviously, PaaS intermediaries also use AWS Cloud. But concealing its cheap solutions with a marketing, 
trying to hook you up on a dodgy contract and making you pay 10 times more.
``` 
<img align="right" src="https://user-images.githubusercontent.com/1591200/119654001-e3338480-be1f-11eb-9f16-e8e4eedc1f07.png">

## AWS cloud account pros:
- Open source Magento
- No license fees
- No draconian contracts
- No hardware configuration restrictions
- No services configuration limitations
- No hidden bottlenecks
- No time waste for [support tickets](https://devdocs.magento.com/cloud/project/services.html)
- Transparent billing
- No sudden surplus resources  
  
  
  
**Amazon Web Services** offers an ecommerce cloud computing solutions to small and large businesses that want a flexible, secured, highly scalable infrastructure. All the technologies online retailers need to manage growth—instantly. With technologies like automatic scaling compute resources, networking, storage, content distribution, and a PCI-compliant environment, retailers can always provide great customer experiences and capitalize on growth opportunities.  

**The biggest benefits of using your own AWS Cloud account**: [Reserved Instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-reserved-instances.html)  
Reserved Instances provide you with significant savings on your Amazon EC2 costs compared to On-Demand Instance pricing. With Savings Plans, you make a commitment to a consistent usage amount, measured in USD per hour. This provides you with the flexibility to use the instance configurations that best meet your needs and continue to save money. 

<br />

## [+] EC2 webstack custom configuration and management
[User data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html) templates with shell scripts. If you are familiar with shell scripting, this is the easiest and most complete way to send instructions to an instance to perform common automated configuration tasks and even run scripts after the instance starts. From default stack optimization to changing any application and service settings.

NGINX is optimized and fully supported on the latest generation of 64-bit ARM Servers utilizing the architecture. PHP using socket connection.

Ubuntu 20.04.2 LTS includes support for the very latest ARM-based server systems powered by certified 64-bit processors.
Develop and deploy at scale. Webstack delivers top performance on ARM.

[**AWS Systems Manager**](https://aws.amazon.com/systems-manager/) is an AWS service that you can use to view and control your infrastructure on AWS. Using the Systems Manager console, you can view operational data from multiple AWS EC2 instances and automate operational tasks across your AWS resources. Systems Manager helps you maintain security and compliance. No SSH connections from outside, no need to track passwords and private keys.

<br />

## Developer documentation to read:
``` 
https://devdocs.magento.com/
https://docs.aws.amazon.com/index.html
https://www.terraform.io/docs/
https://aws.amazon.com/cloudshell/
```
<br />

The terraform configuration language and all the files in this repository are intuitively simple and straightforward. They are written in simple text and functions that any beginner can understand. Terraform deployment with zero dependency, no prerequisites, no need to install additional software, no programming required.

<br />

# Deployment into isolated VPC:
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
- Note: Right after `terraform apply` you will receive email from amazon to approve resources
- Check all details / all files / adjust your settings, edit your domain and email in `variables.tf`
- Run:
```
   terraform init
   terraform apply
```
> to destroy infrastructure: ```terraform destroy```  
> resources created outside of terraform must be deleted manually, for example CloudWatch logs

<br />

## Complete setup:
 `5` autoscaling groups with launch templates converted from `user_data`  
 `4` target groups for load balancer (varnish frontend admin staging)  
 `1` build server to compile all the code  
 `2` load balancers (external/internal) with listeners / rules  
 `2` rds mariadb databases multi AZ production, single AZ staging  
 `1` elasticsearch domain for Magento catalog search  
 `2` redis elasticache cluster for sessions and cache  
 `1` rabbitmq broker to manage queue messages  
 `2` s3 buckets for [media] images and [system] files and logs (with access policy)  
 `1` codecommit repository with 3 branches (main build staging)  
 `1` cloudfront s3 origin distribution  
 `1` efs file system for shared folders, with mount target per AZ  
 `1` sns topic default subscription to receive email alerts  
 `1` ses user access details for smtp module
 
 >resources are grouped into a virtual network, VPC dedicated to your brand  
 >the settings initially imply a large store, and are designed for huge traffic.  
 >services are clustered and replicated thus ready for failover.
 
##
- [x] Deployment into isolated Virtual Private Cloud
- [x] Autoscaling policy per each group, excluding `build` instance
- [x] Managed with [Systems Manager](https://aws.amazon.com/systems-manager/) agent
- [x] Instance Profile assigned to simplify EC2 management
- [x] Create and use ssm documents and EventBridge rules to automate tasks
- [x] Simple Email Service authentication + SMTP Magento module
- [x] CloudWatch agent configured to stream logs
- [x] All Magento files managed with git only
- [x] Live shop in production mode / read-only 
- [x] Security groups configured for every service and instances
- [x] AWS Inspector Assessment templates
- [x] AWS WAF Protection rules

## Magento 2 development | source code:
- Terraform creates CodeCommit repository. Local provisioner copy files from Github https://github.com/magenx/Magento-2. Files saved to AWS CloudShell /tmp directory and pushed to CodeCommit.
- Later on EC2 instance user_data configured on boot to clone files from CodeCommit branch.
- Right after infrastructure deployment the minimal Magento 2 package is ready to install. Run SSM Document to install Magento
> minimal Magento 2 package can be extended anytime. Remove blacklisted components from `composer.json` in `"replace": {}` and run `composer update`  
- Why removing bloatware modules and use Magento minimal package:
  - Faster backend and frontend
  - Easy deployments
  - Less dependencies
  - Zero maintenance
  - Low security risks  

## CI/CD scenario:
- Event driven
- Changes in CodeCommit repository triggers EventBridge rule. By default admin and frontend tagged resources are targets of this rule.
- SSM Document pull from CodeCommit repository and cleanup.
- Change deployment logic to your needs.

## Infrastructure DevOps and beyond:
- Terraform [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- edit => migrate => share

## TODO:
- Proper vars  

## :heart_eyes_cat: Support the project  
This takes time and research. You can use this for free. But for me its not free to create it.
If you are using this project, there are few ways you can support it:
- [x] Star and sharing the project
- [x] Open an issue to help me make it better
- [x] [PAYPAL](https://paypal.me/magenx) - You can make one-time donation.  

##
![Magento_2_AWS_cloud_auto_scaling_magenx-big](https://user-images.githubusercontent.com/1591200/106358223-ac7eaf00-6302-11eb-963e-cc0d0136d88f.png)

<sub>[Magento 2 on the AWS Cloud: Quick Start Deployment](https://www.magenx.com/blog/post/adobe-commerce-cloud-alternative-infrastructure-as-code-terraform-configuration.html)</sub>

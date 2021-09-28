## Magento 2 [auto scaling](https://aws.amazon.com/autoscaling/) cluster with Terraform on AWS cloud
> Deploy a full-scale secure and flexible e-commerce infrastructure based on Magento 2 in a matter of seconds.  
> Enterprise-grade solution for companies of all sizes, B2B B2C, providing the best customer experience.  

<img src="https://user-images.githubusercontent.com/1591200/117845471-7abda280-b278-11eb-8c88-db3fa307ae40.jpeg" width="200" height="140"> <img src="https://user-images.githubusercontent.com/1591200/117845982-edc71900-b278-11eb-81ec-e19465f1344c.jpeg" width="175" height="145"> <img src="https://user-images.githubusercontent.com/1591200/118028531-158ead80-b35b-11eb-8957-636de16ada34.png" width="250" height="155">
<img src="https://user-images.githubusercontent.com/1591200/130320410-91749ce8-5af1-4802-af25-ffb36e7ded98.png" width="120" height="135">

<br />

## AWS Graviton2 Processor - Enabling the best performance in EC2:
![aws-graviton2](https://user-images.githubusercontent.com/1591200/117844857-f0753e80-b277-11eb-9d27-fe8eacdf6c19.png)

<br />

## [?] Why we need Adobe Commerce Cloud alternative:
The biggest issue is that ACC pricing based on GMV % and AOV %, you overpay up to 80%, while the bill between Adobe and AWS remains at a minimum. With this approach, you invest money in the development of a third-party business, but not your own.
Why spend so much money without having control over your business in the cloud?
Configuring your own infrastructure these days is the most profitable way. You manage the resources, you have a complete overview how it works and you have full control over the money invested in your own infrastructure. At any time you can make changes to both infrastructure and application design without thinking about restrictions, 3rd party platform limitations and unforeseen costs. There are no hidden bills and payments for excess resources, which, as a result, you will not need.  

Adobe Commerce Cloud has lots of technical problems due to the fact that many services compete on the same server and share the processor time, memory, network and I/O. Bad architectural solution using monolitic servers, not cloud native solution, that was not made specifically for Magento, but adapted in rush using many wrappers, with manual pseudo scaling and 48 hours to 5 days to accept and deploy new settings.

```
Obviously, PaaS intermediaries also use AWS Cloud. But concealing its cheap solutions with a marketing, 
trying to hook you up on a dodgy contract and making you pay 10 times more.
``` 
<img align="right" width="500" src="https://user-images.githubusercontent.com/1591200/130331243-03e6097a-c380-4586-b380-cbc733237d93.png">

## AWS cloud account pros:
- [x] Open source Magento
- [x] Pay as You Go
- [x] Transparent billing
- [x] No draconian contracts
- [x] No sudden overage charges
- [x] No hardware restrictions
- [x] No services limitations
- [x] No hidden bottlenecks
- [x] No time waste for [support tickets](https://devdocs.magento.com/cloud/project/services.html) 
  
  
&nbsp;  
  
**Amazon Web Services** offers an ecommerce cloud computing solutions to small and large businesses that want a flexible, secured, highly scalable infrastructure. All the technologies online retailers need to manage growth—instantly. With technologies like automatic scaling compute resources, networking, storage, content distribution, and a PCI-compliant environment, retailers can always provide great customer experiences and capitalize on growth opportunities.  

**The biggest benefits of using your own AWS Cloud account**: [Reserved Instances](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-reserved-instances.html)  
Reserved Instances provide you with significant savings on your Amazon EC2 costs compared to On-Demand Instance pricing. With Savings Plans, you make a commitment to a consistent usage amount, measured in USD per hour. This provides you with the flexibility to use the instance configurations that best meet your needs and continue to save money. 

<br />

## [+] EC2 webstack custom configuration and Auto Scaling management
[User data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html) templates with shell scripts. If you are familiar with shell scripting, this is the easiest and most complete way to send instructions to an instance to perform common automated configuration tasks and even run scripts after the instance starts. From default stack optimization to changing any application and service settings.

[**Warm pools** for Amazon EC2 Auto Scaling](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-warm-pools.html) - A warm pool gives you the ability to decrease latency for your applications. With warm pools, you no longer have to over-provision your Auto Scaling groups to manage latency in order to improve application performance. You have the option of keeping instances in the warm pool in one of two states: `Stopped` or `Running`. Keeping instances in a `Stopped` state is an effective way to minimize costs.

NGINX is optimized and fully supported on the latest generation of 64-bit ARM Servers utilizing the architecture. PHP using socket connection.

[**Debian 11** ARM 'bullseye'](https://aws.amazon.com/marketplace/pp/prodview-jwzxq55gno4p4), which will be supported for the next 5 years. Includes support for the very latest ARM-based server systems powered by certified 64-bit processors.
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
  
The idea was to create something more complex, with deeper settings, that terrifies competitors at first sight.

<br />

# :rocket: Deployment into isolated VPC:
- [x] Login to AWS Console
- [x] [Subscribe to Debian 11 ARM](https://aws.amazon.com/marketplace/pp/prodview-jwzxq55gno4p4)
- [x] Choose an AWS Region
- [x] Start AWS CloudShell
- [x] Install Terraform:
```
   sudo yum install -y yum-utils
   sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
   sudo yum -y install terraform
```
- [x] Create deployment directory:  
```
  mkdir magento && cd magento
```
- [x] Clone repo:  
> 
```
  git clone https://github.com/magenx/Magento-2-aws-cluster-terraform.git .
```
>  
**[ ! ]** Note: Right after `terraform apply` you will receive email from amazon to approve resources  
**[ ! ]** Check all user_data, adjust your settings, edit your cidr, brand, domain, email and other vars in `variables.tf`  
- [x] Run:
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
 `2` codecommit app files repository and services config files repository  
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
- [x] Configuration settings saved in Parameter Store
- [x] Live shop in production mode / read-only 
- [x] Security groups configured for every service and instances
- [x] phpMyAdmin for easy database editing
- [x] MariaDB database dump for data analysis
- [x] Enhanced security in AWS and LEMP 
- [x] AWS Inspector Assessment templates
- [x] AWS WAF Protection rules  

##
![Magento_2_AWS_cloud_auto_scaling_terraform-map](https://user-images.githubusercontent.com/1591200/119973444-66351600-bfab-11eb-82b8-1413c9aa41fc.png)

## :hammer_and_wrench: Magento 2 development | source code:
- [x] Local provisioner copy files from https://github.com/magenx/Magento-2
- [x] Pickup files from your own repo @ [variables.tf#L20](https://github.com/magenx/Magento-2-aws-cluster-terraform/blob/main/variables.tf#L20)
- [x] Files saved to AWS CloudShell /tmp directory and pushed to CodeCommit.
- [x] Later on EC2 instance user_data configured on boot to clone files from CodeCommit branch.
- [x] Right after infrastructure deployment the minimal Magento 2 package is ready to install.
- [x] Check and run SSM Document to install Magento and pre-configure modules (select admin instance)
> Replaced over 200+ useless modules. Minimal Magento 2 package can be extended anytime.
> Remove replaced components from `composer.json` in `"replace": {}` and run `composer update`  
> modules configuration here: https://github.com/magenx/Magento-2/blob/main/composer.json  
   
   
|**Performance and security enhancements**||**Enabled modules for test requirements**|
|:-----|---|:-----|
|Faster backend and frontend from 14% upto 50%||[Fooman Email PDF](https://fooman.com/magento-extension-email-attachments-m2.html)|
|Better memory management upto 15%||[Stripe Payments](https://stripe.com/docs/plugins/magento)|
|Easy deployments||[Mageplaza SMTP](https://github.com/mageplaza/magento-2-smtp)|
|Less dependencies||[Magefan Blog](https://github.com/magefan/module-blog)|
|Zero maintenance||[Fooman Order#=Invoice#](https://fooman.com/magento-extension-invoice-order-number-m2.html)|
|Low security risks||[Fooman Print PDF](https://fooman.com/magento-extension-print-order-pdf-m2.html)|

<br />

## CI/CD scenario:
- [x] Event driven
- [x] Services configuration files tracked in CodeCommit repository
- [x] Changes in CodeCommit repository triggers EventBridge rule.
- [x] SSM Document pull from CodeCommit repository and cleanup.
- [x] Change deployment logic to your needs.  
   
<br />
   
## [:e-mail:] Contact us for installation and support:
We can launch this project for your store in a short time. Many big retailers have already migrated to this architecture.
- [x] Write us an [email](mailto:info@magenx.com?subject=Magento%202%20auto%20scaling%20cluster%20on%20AWS) to discuss the project.
- [x] Send a private message on [Linkedin](https://www.linkedin.com/in/magenx/)  
    
<br />
   
## ![hyvatheme](https://user-images.githubusercontent.com/1591200/132108893-0fc007b1-87f0-47a1-b8c1-d6dd3a6dda83.png)
[Hyvä themes](https://hyva.io/hyva-themes-license.html) - Magento 2 frontend alternative to PWA. Hyvä themes is a brand-new frontend for Magento 2 with the best DevOps experience, performance and time to market. With Hyvä, you build your Magento 2 shop quicker and with a lower budget. And the result is a modern and ultra fast browser experience for your visitors. We recommend that you start developing your store using this theme or switch your existing store frontend to this theme.  
    
<br />
    
## :heart_eyes_cat: Support the project  
This takes time and research. You can use this for free. But its not free to create it.
If you are using this project, there are few ways you can support it:
- [x] Star and sharing the project
- [x] Open an issue to help make it better
  
❤️ Opensource  

<sub>[Magento 2 on the AWS Cloud: Quick Start Deployment](https://www.magenx.com/blog/post/adobe-commerce-cloud-alternative-infrastructure-as-code-terraform-configuration.html)</sub>

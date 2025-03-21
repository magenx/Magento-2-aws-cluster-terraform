## Magento 2 [auto scaling](https://aws.amazon.com/autoscaling/) cluster with Terraform on AWS cloud only
> This configuration creates an EC2 instances and replaces all AWS-managed services with self-managed alternatives. Done.  
> Deploy a full-scale secure and flexible e-commerce infrastructure based on Magento 2 in a matter of seconds.  
> Enterprise-grade solution for companies of all sizes, B2B B2C, providing the best customer experience.  
> use [Fastly, Cloudflare, Section](../../tree/fastly_v5) in front 

<img src="https://github.com/user-attachments/assets/11071403-b3cb-4844-a438-f7bc89d55b11">
<br />
<br />

## AWS Graviton4 Processor - Enabling the best performance in EC2:
<img src="https://github.com/user-attachments/assets/45ad089f-2321-46ea-9f02-415ad669801a" width="255" height="160"> <img src="https://github.com/user-attachments/assets/c0213f80-129d-42e4-82e0-0c253240a564" width="255" height="160"> <img src="https://github.com/user-attachments/assets/72aa2031-99d8-44c6-90ea-b63944cd19f7" width="255" height="160">


> [Amazon EC2 C8g instances upgrade](https://aws.amazon.com/ec2/instance-types/c8g/)  
> Best price performance for compute-intensive workloads in Amazon EC2  
  
<br />

## ❓ Why we need Adobe Commerce Cloud alternative:
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

## 📖 EC2 webstack custom configuration and Auto Scaling management
[**Warm pools** for Amazon EC2 Auto Scaling](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-warm-pools.html) - A warm pool gives you the ability to decrease latency for your applications. With warm pools, you no longer have to over-provision your Auto Scaling groups to manage latency in order to improve application performance. You have the option of keeping instances in the warm pool in one of two states: `Stopped` or `Running`. Keeping instances in a `Stopped` state is an effective way to minimize costs.

NGINX is optimized and fully supported on the latest generation of 64-bit ARM Servers utilizing the architecture. PHP using socket connection.

[**Debian 12** ARM 'bookworm'](https://aws.amazon.com/marketplace/pp/prodview-63gms6fbfaota), which will be supported for the next 5 years. Includes support for the very latest ARM-based server systems powered by certified 64-bit processors.
Develop and deploy at scale. Webstack delivers top performance on ARM.

[**AWS Systems Manager**](https://aws.amazon.com/systems-manager/) is an AWS service that you can use to view and control your infrastructure on AWS. Using the Systems Manager console, you can view operational data from multiple AWS EC2 instances and automate operational tasks across your AWS resources. Systems Manager helps you maintain security and compliance. No SSH connections from outside, no need to track passwords and private keys. If you are familiar with shell scripting, yaml and json syntax, create SSM Documents, this is the easiest and most complete way to send instructions to an instance to perform common automated configuration tasks and even run scripts after the instance starts. From default stack optimization to changing any application and service settings.

<br />

## Developer documentation to read:
``` 
https://devdocs.magento.com/
https://docs.aws.amazon.com/index.html
https://www.terraform.io/docs/
https://aws.amazon.com/cloudshell/
https://docs.ansible.com/
```
<br />

The terraform configuration language and all the files in this repository are intuitively simple and straightforward. They are written in simple text and functions that any beginner can understand. Terraform deployment with zero dependency, no prerequisites, no need to install additional software, no programming required.  
  
The idea was to create a full-fledged turnkey infrastructure, with deeper settings, so that any ecommerce manager could deploy it and immediately use it for his brand.


<br />

# :rocket: Deployment into isolated VPC:
- [x] Login to AWS Console
- [x] [Subscribe to Debian 12 ARM](https://aws.amazon.com/marketplace/pp/prodview-63gms6fbfaota)
- [x] Choose an AWS Region
- [x] Start AWS CloudShell [fastest way to deploy and debug]
- [x] Create install script in cloudshell user home:
```
   cat <<'END' > install
   yum install -y yum-utils
   yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
   yum -y install terraform
   mkdir -p /home/magento && cd $_
   git clone https://github.com/magenx/Magento-2-aws-cluster-terraform -b ec2_v5 .
   mv production.auto.tfvars.template production.auto.tfvars
   vim production.auto.tfvars
   bash init.sh
   END
```
- [x] Switch to root user and run quick init script:
```
  sudo -i
  bash ../cloudshell-user/install
```
- [x] Adjust your settings
```
  cd /home/magento
  terraform apply
```
>  
❗ Right after `terraform apply` you will receive email from amazon to approve resources    
  
❗ ```For production deployment make sure to enable deletion protection and backup retention```  
  
❗ Destroy infrastructure: ```terraform destroy```  
❗ Resources created outside of terraform must be deleted manually, for example CloudWatch logs or volumes

<br />

## Complete setup:
 `6` autoscaling groups with launch templates + configuration with `ssm automation` and `ansible playbooks`  
 `1` varnish or frontend target group for load balancer    
 `1` load balancer with listeners / rules  
 `1` ec2 instance mariadb database  
 `1` ec2 instance elasticsearch domain for Magento catalog search  
 `1` ec2 instance redis for sessions and cache  
 `1` ec2 instance rabbitmq broker to manage queue messages  
 `4` s3 buckets for [media] [media-optimized] images [backup] and [system] configuration and release deployments (with access policy)  
 `1` cloudfront s3 and ALB origin distribution  
 `1` lambda@edge function to resize images   
 `1` codedeploy app and group for deployments
 `1` efs file system for shared folders, with mount target per AZ  
 `1` sns topic default subscription to receive email alerts  
 `1` ses user access details for smtp module  
 
 > resources are grouped into a virtual network, VPC dedicated to your brand  
 > the settings initially imply a medium store, and are designed for moderate traffic.  
 > services are clustered and replicated thus ready for failover.
 
##
- [x] Deployment into isolated Virtual Private Cloud
- [x] Autoscaling policy per each group, in case of clustering
- [x] Managed with [Systems Manager](https://aws.amazon.com/systems-manager/) agent
- [x] Instance Profile assigned to simplify EC2 management
- [x] EventBridge rules to automate tasks
- [x] Simple Email Service authentication
- [x] CloudWatch agent configured to stream logs
- [x] Configuration settings saved in Parameter Store
- [x] Codedeploy to deploy application release
- [x] Security groups configured for every instance
- [x] [Lambda@Edge](https://aws.amazon.com/lambda/edge/#Real-time_Image_Transformation) images optimization
- [x] Enhanced security 
- [x] AWS CloudMap for private DNS management
- [x] AWS WAF Protection rules  

##
![Magento_2_AWS_cloud_auto_scaling_terraform-map]()

## 💰 Infracost - shows cloud infrastructure cost estimates:
```
infracost breakdown --path .
INFO Autodetected 1 Terraform project across 1 root module
INFO Found Terraform project main at directory .

Project: main

OVERALL TOTAL       **$630.87 

──────────────────────────────────
318 cloud resources were detected:
∙ 33 were estimated
∙ 282 were free
∙ 3 are not supported yet, rerun with --show-skipped to see details
```
> ** conditionally approximate price per month of this infrastructure.  

<br/>

## :hammer_and_wrench: Magento 2 development:
- [x] Docker for local development - https://github.com/magenx/Magento-2-docker-configuration
- [x] Github Actions build code and push to S3
- [x] EC2 instance configuration with ssm documents on boot to sync configs from S3
- [x] Codedeploy agent creates deployment on S3 release updates
  
> DEMO code: https://github.com/magenx/Magento-2/    
> Replaced over 200+ useless modules. Minimal Magento 2 package can be extended anytime  
> Remove replaced components from `composer.json` in `"replace": {}` and run `composer update`  
> modules configuration here: https://github.com/magenx/Magento-2/blob/main/composer.json  
   

**Performance and security enhancements**
- Faster backend and frontend from 14% upto 50%
- Better memory management upto 15%
- Easy deployments
- Less dependencies
- Zero maintenance
- Low security risks

<br />
   
## :e-mail: Contact us for installation and support:
We can launch this project for your store in a short time. Many big retailers have already migrated to this architecture.
- [x] Write us an [email](mailto:info@magenx.com?subject=Magento%202%20auto%20scaling%20cluster%20on%20AWS) to discuss the project.
- [x] Send a private message on [Linkedin](https://www.linkedin.com/in/magenx/)  
    
<br />
    
## :heart_eyes_cat: Support the project  
This takes time and research. You can use this for free. But its not free to create it.
If you are using this project, there are few ways you can support it:
- [x] Star and sharing the project
- [x] Open an issue to help make it better
- [x] Write a review https://trustpilot.com/review/www.magenx.com  
  
❤️ Opensource  

<sub>[Magento 2 on the AWS Cloud: Quick Start Deployment](https://www.magenx.com/blog/post/adobe-commerce-cloud-alternative-infrastructure-as-code-terraform-configuration.html)</sub>

# #
# Generate random secret strings / passwords
# #
resource "random_password" "password" {
  count            = 3
  length           = 16
  lower            = true
  upper            = true
  number           = true
  special          = true
  override_special = "!#$%&*?"
}
# #
# Extract some vars for launch template, append to user_data*
# #
resource "null_resource" "launch_template_vars" {
  # extract some configuration values
  provisioner "local-exec" {
    command = <<EOF
## Preconfigure user_data. variables
echo AWS_DEFAULT_REGION=\"${data.aws_region.current.name}\" > ./vars
echo CODECOMMIT_MAGENTO_REPO_NAME=\"${aws_codecommit_repository.codecommit_repository.repository_name}\" >> ./vars
echo MAGE_DOMAIN=\"${var.magento["mage_domain"]}\" >> ./vars
echo MAGE_OWNER=\"${var.magento["mage_owner"]}\" >> ./vars
echo MAGE_PHP_USER=\"php-${var.magento["mage_owner"]}\" >> ./vars
echo MAGE_ADMIN_EMAIL=\"${var.magento["mage_admin_email"]}\" >> ./vars
echo MAGE_WEB_ROOT_PATH=\"/home/${var.magento["mage_owner"]}/public_html\" >> ./vars
echo MAGE_TIMEZONE=\"${var.magento["timezone"]}\" >> ./vars
## Inject variables into user_data
find scripts/ -type f -exec rm -rf {} \;
mkdir -p scripts
cp -rf user_data.* scripts/
sed -i '/###VARIABLES_PLACEHOLDER###/ {
r ./vars
N
}' scripts/user_data.*
EOF
on_failure = continue
 }
}
# #
# Create CodeCommit repository for Magento code
# #
resource "aws_codecommit_repository" "codecommit_repository" {
  repository_name = var.magento["mage_domain"]
  description     = "Magento 2.x code for ${var.magento["mage_domain"]}"
    tags = {
    Name = "${var.magento["mage_owner"]}-${var.magento["mage_domain"]}"
  }
}
# #
# Create EFS file system ids
# #
resource "aws_efs_file_system" "efs_file_system" {
  for_each = var.efs_name
  creation_token = "${var.magento["mage_owner"]}-${each.key}-efs"
  tags = {
    Name = "${var.magento["mage_owner"]}-${each.key}-efs"
  }
}
# #
# Create EFS mount targets for each filesystem
# #
resource "aws_efs_mount_target" "efs_mount_target" {
  depends_on = [aws_efs_file_system.efs_file_system]
  for_each = {
    for index in setproduct(values(aws_efs_file_system.efs_file_system)[*].id, data.aws_subnet_ids.subnet_ids.ids) : "${index[0]}-${index[1]}" => {
      file_system_id = index[0]
      subnet_id = index[1]
    }
  }
  file_system_id = each.value.file_system_id
  subnet_id      = each.value.subnet_id
}
# #
# Update SSM preferences
# #
resource "aws_ssm_document" "session_manager_preferences" {
  name            = "SSM-SessionManagerRunShell"
  document_type   = "Session"
  document_format = "JSON"

  content = <<EOF
{
  "schemaVersion": "1.0",
  "description": "Document to hold regional settings for Session Manager",
  "sessionType": "Standard_Stream",
  "inputs": {
    "s3BucketName": "${aws_s3_bucket.s3_bucket["system"].bucket}",
    "s3KeyPrefix": "ssmsessionlogs",
    "s3EncryptionEnabled": true,
    "cloudWatchLogGroupName": "",
    "cloudWatchEncryptionEnabled": false,
    "cloudWatchStreamingEnabled": false,
    "idleSessionTimeout": "30",
    "kmsKeyId": "",
    "runAsEnabled": true,
    "runAsDefaultUser": "",
    "shellProfile": {
      "windows": "",
      "linux": ""
    }
  }
}
EOF
}
# #
# Create SSM YAML Document runShellScript to init/pull git
# #
resource "aws_ssm_document" "ssm_document_pull" {
  name          = "${var.magento["mage_owner"]}-deployment-git"
  document_type = "Command"
  document_format = "YAML"
  target_type   = "/AWS::EC2::Instance"
  content = <<EOT
---
schemaVersion: "2.2"
description: "Pull code changes from codecommit"
parameters:
mainSteps:
- action: "aws:runShellScript"
  name: "codecommitpullchanges"
  inputs:
    runCommand:
    - |-
      #!/bin/bash
      if [ -f /home/${var.magento["mage_owner"]}/public_html/app/etc/env.php ]; then
      cd /home/${var.magento["mage_owner"]}/public_html
      git checkout main
      git pull origin main
      systemctl reload php-fpm
      systemctl reload nginx
      else
      exit 1
      fi
EOT
}
# #
# Create SSM YAML Document runShellScript to init/pull git
# #
resource "aws_ssm_document" "ssm_document_install" {
  name          = "${var.magento["mage_owner"]}-install-magento-git"
  document_type = "Command"
  document_format = "YAML"
  target_type   = "/AWS::EC2::Instance"
  content = <<EOT
---
schemaVersion: "2.2"
description: "Configure git, install magento, push to codecommit"
parameters:
mainSteps:
- action: "aws:runShellScript"
  name: "codecommitinstallmagento"
  inputs:
    runCommand:
    - |-
      #!/bin/bash
      mkdir -p /home/${var.magento["mage_owner"]}/public_html && cd $_
      chmod 711 /home/${var.magento["mage_owner"]}
      mkdir -p /home/${var.magento["mage_owner"]}/{.config,.cache,.local,.composer}
      chown -R ${var.magento["mage_owner"]}:php-${var.magento["mage_owner"]} /home/${var.magento["mage_owner"]}/public_html /home/${var.magento["mage_owner"]}/{.config,.cache,.local,.composer}
      chmod 2770 /home/${var.magento["mage_owner"]}/public_html
      setfacl -Rdm u:${var.magento["mage_owner"]}:rwX,g:php-${var.magento["mage_owner"]}:r-X,o::- /home/${var.magento["mage_owner"]}/public_html
      git config --system credential.helper '!aws codecommit credential-helper $@'
      git config --system credential.UseHttpPath true
      git config --system user.email "${var.magento["mage_admin_email"]}"
      git config --system user.name "${var.magento["mage_owner"]}"
      su ${var.magento["mage_owner"]} -s /bin/bash -c "git clone https://github.com/magenx/Magento-2.git /home/${var.magento["mage_owner"]}/public_html/"
      su ${var.magento["mage_owner"]} -s /bin/bash -c "echo 007 > /home/${var.magento["mage_owner"]}/public_html/magento_umask"
      setfacl -Rdm u:${var.magento["mage_owner"]}:rwX,g:php-${var.magento["mage_owner"]}:rwX,o::- var generated pub/static pub/media
      rm -rf .git
      find . -type d -exec chmod 2770 {} \;
      find . -type f -exec chmod 660 {} \;
      chmod +x bin/magento
      bin/magento module:enable --all
      su ${var.magento["mage_owner"]} -s /bin/bash -c "bin/magento setup:install \
      --base-url=https://${var.magento["mage_domain"]}/ \
      --base-url-secure=https://${var.magento["mage_domain"]}/ \
      --db-host=${aws_db_instance.db_instance.endpoint} \
      --db-name=${var.rds["rds_database"]} \
      --db-user=${var.magento["mage_owner"]} \
      --db-password='${random_password.password[1].result}' \
      --admin-firstname=${var.magento["mage_owner"]} \
      --admin-lastname=${var.magento["mage_owner"]} \
      --admin-email=${var.magento["mage_admin_email"]} \
      --admin-user=admin \
      --admin-password='${random_password.password[2].result}' \
      --language=${var.magento["language"]} \
      --currency=${var.magento["currency"]} \
      --timezone=${var.magento["timezone"]} \
      --cleanup-database \
      --session-save=files \
      --use-rewrites=1 \
      --use-secure=1 \
      --use-secure-admin=1 \
      --consumers-wait-for-messages=0 \
      --search-engine=elasticsearch7 \
      --elasticsearch-host=${aws_elasticsearch_domain.elasticsearch_domain.endpoint} \
      --elasticsearch-port=443 \
      --remote-storage-driver=aws-s3 \
      --remote-storage-bucket=${aws_s3_bucket.s3_bucket["magento"].bucket} \
      --remote-storage-region=${data.aws_region.current.name}"
      ## cache backend
      su ${var.magento["mage_owner"]} -s /bin/bash -c "bin/magento setup:config:set \
      --cache-backend=redis \
      --cache-backend-redis-server=${aws_elasticache_cluster.elasticache_cluster["cache"].cache_nodes.0.address} \
      --cache-backend-redis-port=6379 \
      --cache-backend-redis-db=1 \
      -n"
      ## session
      su ${var.magento["mage_owner"]} -s /bin/bash -c "bin/magento setup:config:set \
      --session-save=redis \
      --session-save-redis-host=${aws_elasticache_cluster.elasticache_cluster["session"].cache_nodes.0.address} \
      --session-save-redis-port=6379 \
      --session-save-redis-log-level=3 \
      --session-save-redis-db=1 \
      --session-save-redis-compression-lib=snappy \
      -n"
      if [ ! -f /home/${var.magento["mage_owner"]}/public_html/app/etc/env.php ]; then
      exit 1
      fi
      git init
      git add . -A
      git commit -m ${var.magento["mage_owner"]}-magento-$(date +'%Y-%m-%d')
      git remote add origin codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.codecommit_repository.repository_name}
      git branch -m main
      git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.codecommit_repository.repository_name} main
EOT
}
# #
# Create EC2 service role
# #
resource "aws_iam_role" "ec2_instance_role" {
  name = "EC2IAMProfile"
  description = "Allows EC2 instances to call AWS services on your behalf"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}
# #
# Attach policies to EC2 service role
# #
resource "aws_iam_role_policy_attachment" "ec2_role_policy_attachment" {
  for_each   = var.ec2_instance_profile_policy
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = each.value
}
# #
# Create EC2 Instance Profile
# #
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "EC2IAMProfile"
  role = aws_iam_role.ec2_instance_role.name
}
# #
# Create ElastiCache - Redis - session + cache
# #
resource "aws_elasticache_cluster" "elasticache_cluster" {
  for_each             = toset(var.redis["redis_name"])
  cluster_id           = "${var.magento["mage_owner"]}-${each.key}-elc"
  engine               = "redis"
  node_type            = var.redis["redis_type"]
  num_cache_nodes      = 1
  parameter_group_name = var.redis["redis_params"]
}
# #
# Create S3 bucket
# #
resource "aws_s3_bucket" "s3_bucket" {
  for_each      = var.s3
  bucket        = "${var.magento["mage_owner"]}-${each.key}-storage"
  force_destroy = true
  acl           = "private"
  tags = {
    Name        = "${var.magento["mage_owner"]}-${each.key}-storage"
  }
}
# #
# Create ElasticSearch service role
# #
resource "aws_iam_service_linked_role" "elasticsearch_domain" {
  aws_service_name = "es.amazonaws.com"
}
# #
# Create ElasticSearch domain !!! ~45min creation time
# #
resource "aws_elasticsearch_domain" "elasticsearch_domain" {
  depends_on = [aws_iam_service_linked_role.elasticsearch_domain]
  domain_name           = var.elk["elk_domain"]
  elasticsearch_version = var.elk["elk_ver"]
  cluster_config {
    instance_type  = var.elk["elk_type"]
    instance_count = "1"
  }
  ebs_options {
    ebs_enabled = var.elk["elk_ebs_enabled"]
    volume_type = var.elk["elk_ebs_type"]
    volume_size = var.elk["elk_ebs"]
  }
  vpc_options {
    subnet_ids = [sort(data.aws_subnet_ids.subnet_ids.ids)[0]]
    security_group_ids = [data.aws_security_group.security_group.id]
  }
  tags = {
    Name = var.elk["elk_domain"]
  }
  access_policies = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "*"
        ]
      },
      "Action": [
        "es:*"
      ],
      "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.elk["elk_domain"]}/*"
    }
  ]
}
EOF
}
# #
# Create RDS instance
# #
resource "aws_db_instance" "db_instance" {
  identifier            = "${var.magento["mage_owner"]}-database"
  allocated_storage     = var.rds["rds_storage"]
  max_allocated_storage = var.rds["rds_max_storage"]
  storage_type          = var.rds["rds_storage_type"] 
  engine                = var.rds["rds_engine"]
  engine_version        = var.rds["rds_version"]
  instance_class        = var.rds["rds_class"]
  name                  = var.rds["rds_database"]
  username              = var.magento["mage_owner"]
  password              = random_password.password[1].result
  parameter_group_name  = var.rds["rds_params"]
  skip_final_snapshot   = var.rds["rds_skip_snap"]
  copy_tags_to_snapshot = true
  tags = {
    Name = "${var.magento["mage_owner"]}-database"
  }
}
# #
# Create Application Load Balancer loop names
# #
resource "aws_lb" "load_balancer" {
  for_each           = var.load_balancer_name
  name               = "${var.magento["mage_owner"]}-${each.key}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.aws_security_group.security_group.id]
  subnets            = data.aws_subnet_ids.subnet_ids.ids
  tags = {
    Name = "${var.magento["mage_owner"]}-${each.key}-alb"
  }
}
# #
# Create Target Groups for Load Balancers
# #
resource "aws_lb_target_group" "target_group" {
  for_each    = var.ec2
  name        = "${var.magento["mage_owner"]}-${each.key}-target"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
}
# #
# Create EC2 instances for build and developer systems
# #
resource "aws_instance" "instances" {
  for_each      = var.ec2_extra
  ami           = data.aws_ami.ubuntu_2004.id
  instance_type = each.value
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  vpc_security_group_ids = [data.aws_security_group.security_group.id]
  root_block_device {
      volume_size = "100"
      volume_type = "gp3"
    }
  tags = {
    Name = "${var.magento["mage_owner"]}-${each.key}-ec2"
  }
  volume_tags = {
    Name = "${var.magento["mage_owner"]}-${each.key}-ec2"
  }
  user_data = filebase64("./scripts/user_data.${each.key}")
}
# #
# Create Launch Template for Autoscaling Groups - user_data converted
# #
resource "aws_launch_template" "launch_template" {
  for_each = var.ec2
  name = "${var.magento["mage_owner"]}-${each.key}-lt"
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs { 
        volume_size = "100"
        volume_type = "gp3"
            }
  }
  iam_instance_profile { name = aws_iam_instance_profile.ec2_instance_profile.name }
  image_id = data.aws_ami.ubuntu_2004.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = each.value
  monitoring { enabled = false }
  network_interfaces { 
    associate_public_ip_address = true
    security_groups = [data.aws_security_group.security_group.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.magento["mage_owner"]}-${each.key}-ec2" }
  }
  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.magento["mage_owner"]}-${each.key}-ec2" }
  }
  user_data = filebase64("./scripts/user_data.${each.key}")
}
# #
# Create Autoscaling Groups
# #
resource "aws_autoscaling_group" "autoscaling_group" {
  for_each = var.ec2
  name = "${var.magento["mage_owner"]}-${each.key}-asg"
  vpc_zone_identifier = data.aws_subnet_ids.subnet_ids.ids
  desired_capacity   = var.asg["asg_des"]
  max_size           = var.asg["asg_max"]
  min_size           = var.asg["asg_min"]
  target_group_arns  = [aws_lb_target_group.target_group[each.key].arn]
  launch_template {
    name    = aws_launch_template.launch_template[each.key].name
    version = "$Latest"
  }
}
# #
# Create https:// listener for OUTER Load Balancer - forward to varnish
# #
resource "aws_lb_listener" "outerhttps" {
  load_balancer_arn = aws_lb.load_balancer["outer"].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2020-10"
  certificate_arn   = data.aws_acm_certificate.issued.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group["varnish"].arn
  }
}
# #
# Create http:// listener for OUTER Load Balancer - redirect to https://
# #
resource "aws_lb_listener" "outerhttp" {
  load_balancer_arn = aws_lb.load_balancer["outer"].arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
# #
# Create default listener for INNER Load Balancer - forward to frontend
# #
resource "aws_lb_listener" "inner" {
  load_balancer_arn = aws_lb.load_balancer["inner"].arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group["frontend"].arn
  }
}
# #
# Create conditional listener rule for INNER Load Balancer - forward to admin
# #
resource "aws_lb_listener_rule" "inneradmin" {
  listener_arn = aws_lb_listener.inner.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group["admin"].arn
  }
  condition {
    path_pattern {
      values = ["/${var.magento["admin_path"]}/*"]
    }
  }
}
# #
# Create conditional listener rule for INNER Load Balancer - forward to staging
# #
resource "aws_lb_listener_rule" "innerstaging" {
  listener_arn = aws_lb_listener.inner.arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group["staging"].arn
  }
  condition {
    host_header {
	values = [var.magento["mage_staging_domain"]]
    }
  }
}
# #
# Create conditional listener rule for INNER Load Balancer - forward to developer
# #
resource "aws_lb_listener_rule" "innerdeveloper" {
  listener_arn = aws_lb_listener.inner.arn
  priority     = 30
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group["developer"].arn
  }
  condition {
    host_header {
	values = [var.magento["mage_developer_domain"]]
    }
  }
}
# #
# Create Autoscaling policy for scale OUT
# #
resource "aws_autoscaling_policy" "autoscaling_policy_out" {
  for_each               = var.ec2
  name                   = "${var.magento["mage_owner"]}-${each.key}-asp-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group[each.key].name
}
# #
# Create CloudWatch alarm metric to execute Autoscaling policy for scale OUT
# #
resource "aws_cloudwatch_metric_alarm" "cloudwatch_metric_alarm_out" {
  for_each            = var.ec2
  alarm_name          = "${var.magento["mage_owner"]}-${each.key} scale-out alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.asp["asp_eval_periods"]
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.asp["asp_period"]
  statistic           = "Average"
  threshold           = var.asp["asp_out_threshold"]
  dimensions = {
    AutoScalingGroupName  = aws_autoscaling_group.autoscaling_group[each.key].name
  }
  alarm_description = "${each.key} scale-out alarm - CPU exceeds 60 percent"
  alarm_actions     = [aws_autoscaling_policy.autoscaling_policy_out[each.key].arn]
}
# #
# Create Autoscaling policy for scale IN
# #
resource "aws_autoscaling_policy" "autoscaling_policy_in" {
  for_each               = var.ec2
  name                   = "${var.magento["mage_owner"]}-${each.key}-asp-in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group[each.key].name
}
# #
# Create CloudWatch alarm metric to execute Autoscaling policy for scale IN
# #
resource "aws_cloudwatch_metric_alarm" "cloudwatch_metric_alarm_in" {
  for_each            = var.ec2
  alarm_name          = "${var.magento["mage_owner"]}-${each.key} scale-in alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.asp["asp_eval_periods"]
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.asp["asp_period"]
  statistic           = "Average"
  threshold           = var.asp["asp_in_threshold"]
  dimensions = {
    AutoScalingGroupName  = aws_autoscaling_group.autoscaling_group[each.key].name
  }
  alarm_description = "${each.key} scale-in alarm - CPU less than 25 percent"
  alarm_actions     = [aws_autoscaling_policy.autoscaling_policy_in[each.key].arn]
}
# #
# Create CloudWatch events service role
# #
resource "aws_iam_role" "eventsbridge_service_role" {
  name = "EventsBridgeServiceRole"
  description = "Provides EventsBridge manage events on your behalf."
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "events.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}
# #
# Attach policies to CloudWatch events role
# #
resource "aws_iam_role_policy_attachment" "eventsbridge_role_policy_attachment" {
  for_each   = var.eventsbridge_policy
  role       = aws_iam_role.eventsbridge_service_role.name
  policy_arn = each.value
}
# #
# Create CloudWatch events rule to monitor CodeCommit magento repository state
# #
resource "aws_cloudwatch_event_rule" "eventsbridge_rule" {
  name        = "EventsBridgeRuleCodeCommitRepositoryStateChange"
  description = "CloudWatch monitor magento repository state change"
  event_pattern = <<EOF
{
	"source": ["aws.codecommit"],
	"detail-type": ["CodeCommit Repository State Change"],
	"resources": ["${aws_codecommit_repository.codecommit_repository.arn}"],
	"detail": {
		"referenceType": ["branch"],
		"referenceName": ["main"]
	}
}
EOF
}
# #
# Create EventsBridge target to execute AWS-RunShellScript
# #
resource "aws_cloudwatch_event_target" "eventsbridge_target" {
  rule      = aws_cloudwatch_event_rule.eventsbridge_rule.name
  target_id = "EventsBridgeTargetGitDeploymentScript"
  arn       = aws_ssm_document.ssm_document_pull.arn
  role_arn  = aws_iam_role.eventsbridge_service_role.arn
 
run_command_targets {
    key    = "tag:Name"
    values = ["${var.magento["mage_owner"]}-admin-ec2"]
  }
}

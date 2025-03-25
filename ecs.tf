


/////////////////////////////////////////////////////[ AWS ECS CONFIGURATION ]////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create ecs cluster
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ecs_cluster" "this" {
  name  = "${local.project}-ecs-cluster"
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name     = "${local.project}-ecs-cluster"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ecs service for project application
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ecs_service" "this" {
  name                               = "${local.project}-ecs-service"
  iam_role                           = aws_iam_role.ecs_service_role.arn
  cluster                            = aws_ecs_cluster.this.id
  task_definition                    = aws_ecs_task_definition.this.arn
  desired_count                      = var.ecs["desired_count"]
  deployment_minimum_healthy_percent = var.ecs["tdeployment_minimum_healthy_percent"]
  deployment_maximum_percent         = var.ecs["deployment_maximum_percent"]
  load_balancer {
    target_group_arn = aws_alb_target_group.this.arn
    container_name   = var.ecs["service_name"]
    container_port   = var.ecs["container_port"]
  }
  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }
  ordered_placement_strategy {
    type  = "binpack"
    field = "memory"
  }
  lifecycle {
    ignore_changes = [desired_count]
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ecs task definition
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ecs_task_definition" "this" {
  family             = "${local.project}-ecs-task"
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.ecs_task_iam_role.arn
  volume {
    name = "${local.project}-ecs-storage"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.this.id
      root_directory          = "/data"
    }
  }
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
  container_definitions = jsonencode([
    {
      name         = var.ecs["service_name"]
      image        = var.ecs["service_image"]
      cpu          = var.ecs["cpu_units"]
      memory       = var.ecs["memory"]
      essential    = true
      portMappings = [
        {
          containerPort = var.ecs["container_port"]
          hostPort      = var.ecs["host_port"]
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options   = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name,
          "awslogs-region"        = data.aws_region.current.name,
          "awslogs-stream-prefix" = var.ecs["service_name"]
        }
      }
    }
  ])
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create ecs cloudwatch log group
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/${local.project}/ecs/"
  retention_in_days = 90
}

# # ---------------------------------------------------------------------------------------------------------------------#
# Create role to manage the ECS Cluster
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role" "ecs_service_role" {
  name               = "${local.project}_ECSServiceRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_service_policy.json
}
data "aws_iam_policy_document" "ecs_service_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com",]
    }
  }
}
resource "aws_iam_role_policy" "ecs_service_role_policy" {
  name   = "${local.project}_ECSServiceRolePolicy"
  policy = data.aws_iam_policy_document.ecs_service_role_policy.json
  role   = aws_iam_role.ecs_service_role.id
}
data "aws_iam_policy_document" "ecs_service_role_policy" {
  statement {
    effect  = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:Describe*",
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:RegisterTargets",
      "ec2:DescribeTags",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutSubscriptionFilter",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

# # ---------------------------------------------------------------------------------------------------------------------#
# Create role for ECS Task execution
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${local.project}_ECSTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.task_assume_role_policy.json
}
data "aws_iam_policy_document" "task_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role" "ecs_task_iam_role" {
  name               = "${local.project}_ECSTaskIAMRole"
  assume_role_policy = data.aws_iam_policy_document.task_assume_role_policy.json
}

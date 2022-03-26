


////////////////////////////////////////////////////////[ SECURITY GROUPS ]///////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create security group and rules for ALB
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_security_group" "alb" {
  name        = "${local.project}-alb-sg"
  description = "Security group rules for ${local.project} ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
      description      = "Allow all inbound traffic on the load balancer https listener port"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  
  ingress {
      description      = "Allow all inbound traffic on the load balancer http listener port"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"] 
    }

  egress {
      description      = "Allow outbound traffic to instances on the load balancer listener port"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      security_groups  = [aws_security_group.ec2.id]
    }

  tags = {
    Name = "${local.project}-alb-sg"
  }
}

# # ---------------------------------------------------------------------------------------------------------------------#
# Create security group and rules for EC2
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_security_group" "ec2" {
  name        = "${local.project}-ec2-sg"
  description = "Security group rules for ${local.project} EC2"
  vpc_id      = aws_vpc.this.id
  
  tags = {
    Name = "${local.project}-ec2-sg"
  }
}

resource "aws_security_group_rule" "ec2_https_out" {
    type        = "egress"
    description = "Allow outbound traffic on the instance https port"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.ec2.id
    }

resource "aws_security_group_rule" "ec2_http_out" {
    type        = "egress"
    description = "Allow outbound traffic on the instance http port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.ec2.id
    }

resource "aws_security_group_rule" "ec2_mysql_out" {
    type        = "egress"
    description = "Allow outbound traffic on the instance MySql port"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    source_security_group_id = aws_security_group.rds.id
    security_group_id = aws_security_group.ec2.id
    }

resource "aws_security_group_rule" "ec2_rabbitmq_out" {
    type        = "egress"
    description = "Allow outbound traffic on the instance RabbitMQ port"
    from_port   = 5671
    to_port     = 5671
    protocol    = "tcp"
    source_security_group_id = aws_security_group.rabbitmq.id
    security_group_id = aws_security_group.ec2.id
    }

resource "aws_security_group_rule" "ec2_redis_cache_out" {
    type        = "egress"
    description = "Allow outbound traffic on the instance Redis port"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    source_security_group_id = aws_security_group.redis.id
    security_group_id = aws_security_group.ec2.id
    }

resource "aws_security_group_rule" "ec2_efs_out" {
    type        = "egress"
    description = "Allow outbound traffic on the instance NFS port"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    source_security_group_id = aws_security_group.efs.id
    security_group_id = aws_security_group.ec2.id
    }

resource "aws_security_group_rule" "ec2_ses_out" {
    type        = "egress"
    description = "Allow outbound traffic on the region SES port"
    from_port   = 587
    to_port     = 587
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.ec2.id
    }

resource "aws_security_group_rule" "ec2_elk_out" {
    type        = "egress"
    description = "Allow outbound traffic on the instance ELK port"
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    source_security_group_id = aws_security_group.elk.id
    security_group_id = aws_security_group.ec2.id
    }

resource "aws_security_group_rule" "ec2_http_in_ec2" {
    type        = "ingress"
    description = "Allow all inbound traffic from ec2 on http port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = aws_security_group.ec2.id
    security_group_id = aws_security_group.ec2.id
    }

resource "aws_security_group_rule" "ec2_http_in" {
    type        = "ingress"
    description = "Allow all inbound traffic from the load balancer on http port"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    source_security_group_id = aws_security_group.alb.id
    security_group_id = aws_security_group.ec2.id
    }

# # ---------------------------------------------------------------------------------------------------------------------#
# Create security group and rules for RDS
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_security_group" "rds" {
  name        = "${local.project}-rds-sg"
  description = "Security group rules for ${local.project} RDS"
  vpc_id      = aws_vpc.this.id

  ingress {
      description      = "Allow all inbound traffic to MySQL port from EC2"
      from_port        = 3306
      to_port          = 3306
      protocol         = "tcp"
      security_groups  = [aws_security_group.ec2.id]
    }

  tags = {
    Name = "${local.project}-rds-sg"
  }
}

# # ---------------------------------------------------------------------------------------------------------------------#
# Create security group and rules for ElastiCache
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_security_group" "redis" {
  name        = "${local.project}-redis-sg"
  description = "Security group rules for ${local.project} ElastiCache"
  vpc_id      = aws_vpc.this.id

  ingress {
      description      = "Allow all inbound traffic to Redis port from EC2"
      from_port        = 6379
      to_port          = 6379
      protocol         = "tcp"
      security_groups  = [aws_security_group.ec2.id]
    }

  tags = {
    Name = "${local.project}-redis-sg"
  }
}

# # ---------------------------------------------------------------------------------------------------------------------#
# Create security group and rules for RabbitMQ
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_security_group" "rabbitmq" {
  name        = "${local.project}-rabbitmq-sg"
  description = "Security group rules for ${local.project} RabbitMQ"
  vpc_id      = aws_vpc.this.id

  ingress {
      description      = "Allow all inbound traffic to RabbitMQ port from EC2"
      from_port        = 5671
      to_port          = 5671
      protocol         = "tcp"
      security_groups  = [aws_security_group.ec2.id]
    }

  tags = {
    Name = "${local.project}-rabbitmq-sg"
  }
}

# # ---------------------------------------------------------------------------------------------------------------------#
# Create security group and rules for EFS
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_security_group" "efs" {
  name        = "${local.project}-efs-sg"
  description = "Security group rules for ${local.project} EFS"
  vpc_id      = aws_vpc.this.id

  ingress {
      description      = "Allow all inbound traffic to EFS port from EC2"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      security_groups  = [aws_security_group.ec2.id]
    }
 
  egress {
      description      = "Allow all outbound traffic to EC2 port from EFS"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      security_groups  = [aws_security_group.ec2.id]
    }

  tags = {
    Name = "${local.project}-efs-sg"
  }
}

# # ---------------------------------------------------------------------------------------------------------------------#
# Create security group and rules for ELK
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_security_group" "elk" {
  name        = "${local.project}-elk-sg"
  description = "Security group rules for ${local.project} ELK"
  vpc_id      = aws_vpc.this.id

  ingress {
      description      = "Allow all inbound traffic to ELK port from EC2"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      security_groups  = [aws_security_group.ec2.id]
    }
  
  egress {
      description      = "Allow all outbound traffic to EC2 port from ELK"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      security_groups  = [aws_security_group.ec2.id]
    }

  tags = {
    Name = "${local.project}-elk-sg"
  }
}

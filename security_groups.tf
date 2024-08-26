


////////////////////////////////////////////////////////[ SECURITY GROUPS ]///////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create security group and rules for External ALB
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_security_group" "alb" {
  name        = "${local.project}-alb-sg"
  description = "Security group rules for ${local.project} ALB"
  vpc_id      = aws_vpc.this.id
  tags = {
    Name = "${local.project}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb" {
  description       = "Security group rules for ALB ingress"
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  tags = {
    Name = "${local.project}-alb-ingress-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "alb" {
  description       = "Security group rules for ALB egress"
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  tags = {
    Name = "${local.project}-alb-egress-sg"
  }
}




resource "aws_security_group" "ec2" {
  for_each    = var.ec2
  name        = "${local.project}-${each.key}-sg"
  description = "Security group for ${each.key} EC2"
  vpc_id      = aws_vpc.this.id
  tags = {
    Name = "${local.project}-${each.key}-sg"
  }
}

locals {
  service_sgs = { for k, v in aws_security_group.ec2 : k => v.id if var.ec2[k].service != null }
}

resource "aws_vpc_security_group_ingress_rule" "frontend_alb" {
  security_group_id = aws_security_group.ec2["frontend"].id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol  = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "admin_alb" {
  security_group_id = aws_security_group.ec2["admin"].id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol  = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "frontend_service" {
  for_each = local.service_sgs
  security_group_id = aws_security_group.ec2["frontend"].id
  referenced_security_group_id = each.value
  ip_protocol  = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "admin_service" {
  for_each = local.service_sgs
  security_group_id = aws_security_group.ec2["admin"].id
  referenced_security_group_id = each.value
  ip_protocol  = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "service_frontend" {
  for_each = local.service_sgs
  referenced_security_group_id = aws_security_group.ec2["frontend"].id
  security_group_id = each.value
  ip_protocol  = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "service_admin" {
  for_each = local.service_sgs
  referenced_security_group_id = aws_security_group.ec2["admin"].id
  security_group_id = each.value
  ip_protocol  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  for_each = aws_security_group.ec2
  security_group_id = each.value.id
  ip_protocol  = "-1"
  cidr_ipv4    = values(aws_subnet.this).0.cidr_block
}

# # ---------------------------------------------------------------------------------------------------------------------#
# Create security group and rules for EFS
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_security_group" "efs" {
  name        = "${local.project}-efs-sg"
  description = "Security group rules for EFS"
  vpc_id      = aws_vpc.this.id
  tags = {
    Name = "${local.project}-efs-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "efs" {
  for_each = aws_security_group.ec2
  referenced_security_group_id = each.value.id
  security_group_id = aws_security_group.efs.id
  ip_protocol  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "efs" {
  security_group_id = aws_security_group.efs.id
  ip_protocol  = "-1"
  cidr_ipv4    = values(aws_subnet.this).0.cidr_block
}

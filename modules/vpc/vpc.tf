


////////////////////////////////////////////////////////[ VPC NETWORKING ]////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_vpc" "this" {
  cidr_block           = var.app["cidr_block"]
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${local.project}-vpc"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create subnets for each AZ in our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_subnet" "this" {
  for_each                = data.aws_availability_zone.all
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 4, var.az_number[each.value.name_suffix])
  map_public_ip_on_launch = true
  tags = {
    Name = "${local.project}-subnet"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create internet gateway in our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${local.project}-internet-gateway"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create route table in our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_route" "this" {
  route_table_id         = aws_vpc.this.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Assign AZ subnets to route table in our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_route_table_association" "this" {
  for_each       = aws_subnet.this
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_vpc.this.main_route_table_id
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create DHCP options in our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_vpc_dhcp_options" "this" {
  domain_name          = "${data.aws_region.current.name}.compute.internal"
  domain_name_servers  = ["AmazonProvidedDNS"]
  tags = {
    Name = "${local.project}-dhcp"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Assign DHCP options to our dedicated VPC
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_vpc_dhcp_options_association" "this" {
  vpc_id          = aws_vpc.this.id
  dhcp_options_id = aws_vpc_dhcp_options.this.id
}


# # ---------------------------------------------------------------------------------------------------------------------#
# Private subnet with NAT Gateway
# # ---------------------------------------------------------------------------------------------------------------------#
# # ---------------------------------------------------------------------------------------------------------------------#
# Create NAT Gateway for private subnet
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_nat_gateway" "private" {
  allocation_id = aws_eip.private.id
  subnet_id     = values(aws_subnet.this).0.id

  tags = {
    Name = "${local.project}-nat-gateway"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Assign IP for NAT Gateway
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_eip" "private" {
  depends_on = [aws_internet_gateway.this]
  vpc        = true

  tags = {
    Name = "${local.project}-eip-nat-gateway"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create private subnet
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 4, 15)
  availability_zone       = values(data.aws_availability_zone.all).0.id

  tags = {
    Name = "${local.project}-private-subnet"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create route table for NAT Gateway
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.private.id
  }

  tags = {
    Name = "${local.project}-route-table"
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Associate route table
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}




///////////////////////////////////////////////////////[ CLOUDMAP DISCOVERY ]/////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create CloudMap discovery service with private dns namespace
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = "${var.brand}.internal"
  description = "Namespace for ${local.project}"
  vpc         = aws_vpc.this.id
  tags = {
    Name = "${local.project}-namespace"
  }
}

resource "aws_service_discovery_service" "this" {
  for_each = {
    for entry in setproduct(keys(var.ec2), slice(keys(data.aws_availability_zone.all), 0, 2)) :
      "${entry[0]}-${entry[1]}" => { 
        service = entry[0], 
        az      = entry[1] 
      } 
  }
  name = "${local.project}-${each.value.service}-${each.value.az}"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id
    dns_records {
      type = "A"
      ttl  = 10
    }
  }
  health_check_custom_config {
    failure_threshold = 1
  }
  force_destroy = true
  tags = {
    Name = "${local.project}-${each.value.service}-${each.value.az}-service"
  }
}




//////////////////////////////////////////////////////[ MARIADB DATA EBS VOLUME ]/////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create EBS Volume for MariaDB data storage
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ebs_volume" "mariadb_data" {
  availability_zone = values(aws_subnet.this).0.id
  size              = 250
  type              = "gp3"
  final_snapshot    = true
  
  tags = {
    Name = "mariadb.${var.magento["brand"]}.internal"
  }
}

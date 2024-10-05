


//////////////////////////////////////////////////////[ MARIADB DATA EBS VOLUME ]/////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create EBS Volume for MariaDB data storage
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_ebs_volume" "mariadb_data" {
  availability_zone = values(aws_subnet.this).0.availability_zone
  size              = 250
  type              = "gp3"
  final_snapshot    = true
  encrypted         = true 
  tags = {
    Name = "mariadb.${var.brand}.internal"
  }
}

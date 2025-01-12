


///////////////////////////////////////////////////[ ELASTIC FILE SYSTEM ]////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create EFS file system
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_efs_file_system" "this" {
  creation_token = "${local.project}-efs-storage"
  tags = merge(
         local.default_tags,
         {
    Name = "${local.project}-efs-storage"
  }
)
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EFS mount target for each subnet
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_efs_mount_target" "this" {
  for_each        = aws_subnet.this
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = aws_subnet.this[each.key].id
  security_groups = [aws_security_group.efs.id]
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create EFS access point for each path
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_efs_access_point" "this" {
  for_each = var.efs
  file_system_id = aws_efs_file_system.this.id
  posix_user {
    uid = each.value.uid
    gid = each.value.gid
  }
  root_directory {
    path = "/${each.key}"
    creation_info {
      owner_uid   = each.value.uid
      owner_gid   = each.value.gid
      permissions = each.value.permissions
    }
  }
}

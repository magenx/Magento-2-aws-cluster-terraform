


////////////////////////////////////////////////////////[ CODECOMMIT ]////////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodeCommit repository for magento code
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_codecommit_repository" "magento" {
  repository_name = var.magento["domain"]
  description     = "Magento 2.x code for ${local.project}"
  tags = {
    Name = "${local.project}"
  }
  provisioner "local-exec" {
  interpreter = ["/bin/bash", "-c"]
  command = <<EOF
          mkdir -p /tmp/magento && cd /tmp/magento
          git init
          git config --global user.name "${var.magento["brand"]}"
          git config --global user.email "${var.magento["admin_email"]}"
          git remote set-url origin codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.magento.repository_name}
          git commit --allow-empty -m "init"
          git branch -m main
          git push origin main
          rm -rf /tmp/magento
EOF
  }
}

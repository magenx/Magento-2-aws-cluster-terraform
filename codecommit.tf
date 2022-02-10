


////////////////////////////////////////////////////////[ CODECOMMIT ]////////////////////////////////////////////////////

# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodeCommit repository for application code
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_codecommit_repository" "app" {
  repository_name = var.app["domain"]
  description     = "Magento 2.x code for ${local.project}"
    tags = {
    Name = "${local.project}"
  }
  provisioner "local-exec" {
  interpreter = ["/bin/bash", "-c"]
  command = <<EOF
          mkdir -p /tmp/magento && cd /tmp/magento
          git init
          git config --global user.name "${var.app["admin_firstname"]}"
          git config --global user.email "${var.app["admin_email"]}"
          git remote set-url origin codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.app.repository_name}
          git commit --allow-empty -m "init"
          git branch -m main
          git push origin main
          git checkout -b build
          git push origin build
          rm -rf /tmp/magento
EOF
  }
}
# # ---------------------------------------------------------------------------------------------------------------------#
# Create CodeCommit repository for services configuration
# # ---------------------------------------------------------------------------------------------------------------------#
resource "aws_codecommit_repository" "services" {
  repository_name = "${local.project}-services-config"
  description     = "EC2 linux and services configurations"
    tags = {
      Name = "${local.project}-services-config"
  }
  provisioner "local-exec" {
  interpreter = ["/bin/bash", "-c"]
  command = <<EOF
          cd ${abspath(path.root)}/services/nginx
          git init
          git commit --allow-empty -m "main branch"
          git branch -m main
          git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.services.repository_name} main

          git branch -m nginx_admin
          git add .
          git commit -m "nginx_ec2_config"
          git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.services.repository_name} nginx_admin

          git branch -m nginx_frontend
          git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.services.repository_name} nginx_frontend
          rm -rf .git

          cd ${abspath(path.root)}/services/varnish
          git init
          git branch -m varnish
          git add .
          git commit -m "varnish_ec2_config"
          git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.services.repository_name} varnish
          rm -rf .git
EOF
  }
}



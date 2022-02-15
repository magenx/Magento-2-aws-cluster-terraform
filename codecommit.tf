


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
          git clone ${var.app["source"]} /tmp/magento
          cd /tmp/magento
          git remote add origin codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.app.repository_name}
          git branch -m main
          git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.app.repository_name} main
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
          git add .
          git commit -m "varnish_ec2_config"
          git branch -m varnish
          git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.services.repository_name} varnish
          rm -rf .git
          cd ${abspath(path.root)}/services/systemd_varnish
          git init
          git add .
          git commit -m "systemd_varnish_ec2_config"
          git branch -m systemd_varnish
          git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.services.repository_name} systemd_varnish
          rm -rf .git
          cd ${abspath(path.root)}/services/nginx_varnish
          git init
          git add .
          git commit -m "nginx_varnish_ec2_config"
          git branch -m nginx_varnish
          git push codecommit::${data.aws_region.current.name}://${aws_codecommit_repository.services.repository_name} nginx_varnish
          rm -rf .git
EOF
  }
}



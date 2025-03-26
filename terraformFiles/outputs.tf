output "Web_ip" {
  value = aws_instance.Web.public_ip
}

output "App_ip" {
  value = aws_instance.App.private_ip
}

output "s3_website_url" {
  value = data.aws_s3_bucket.tf3tierbucket.website_endpoint
}

output "rds_endpoint" {
  value = aws_db_instance.my_rds.endpoint
}

output "backend_url" {
  value = aws_lb.external_alb.dns_name
}

output "db_username" {
  value = var.db_username
}

output "db_password" {
  value = var.db_password
}
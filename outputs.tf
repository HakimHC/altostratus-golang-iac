output "lb_domain" {
  value = module.alb.dns_name
}

output "test" {
  value = module.secrets.secret_arns["JWTSECRET"]
}

output "jwt_secret" {
  value = nonsensitive(local.jwt_secret)
}

output "logs" {
  value = aws_cloudwatch_log_group.api.name
}

output "vpc" {
  value = module.vpc.vpc_cidr_block
}
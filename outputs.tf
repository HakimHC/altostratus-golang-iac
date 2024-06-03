output "lb_domain" {
  value = module.alb.dns_name
}

output "test" {
  value = module.secrets.secret_arns["JWTSECRET"]
}
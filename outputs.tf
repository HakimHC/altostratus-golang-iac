output "test" {
  value = local.account_id
}

output "lb_domain" {
  value = aws_lb.this.dns_name
}

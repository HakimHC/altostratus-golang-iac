output "secret_arns" {
  value       = { for k, secret in aws_secretsmanager_secret.this : k => secret.arn }
  description = "The ARNs of the Secrets Manager secrets"
}

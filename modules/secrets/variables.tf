variable "secrets" {
  description = "Key value pairs of secrets"
  type = map(string)
}

variable "recovery_window_in_days" {
  description = "(Optional) Specifies the number of days that AWS Secrets Manager waits before it can delete the secret. This value can be 0 to force deletion without recovery or range from 7 to 30 days. The default value is 30."
  type = number
  default = 0
}
variable "region" {
  type        = string
  description = "AWS Region"
  default     = "eu-west-1"
}

variable "project" {
  type        = string
  description = "Name of this project."
  default     = "altostratus-golang"
}

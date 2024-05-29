variable "region" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-1"
}

variable "project" {
  description = "Name of this project."
  type        = string
  default     = "altostratus-golang"
}

variable "git_provider" {
  description = "CodeStarConnection source provider type"
  type        = string
  default     = "GitHub"
}

variable "api_source_repo_id" {
  description = "ID of the source repository of the api service. Example: foo_user/bar_project"
  type        = string
  default     = "HakimHC/altostratus-golang-api"
}

variable "auth_source_repo_id" {
  description = "ID of the source repository of the auth service. Example: foo_user/bar_project"
  type        = string
  default     = "HakimHC/altostratus-golang-auth"
}
variable "name" {
  description = "Name of the codebuild project"
  type        = string
}

variable "description" {
  description = "Description of the codebuild project"
  type        = string
  default     = null
}

variable "service_role" {
  description = "Role ARN for the codebuild project"
  type        = string
}

variable "artifact_type" {
  description = "Artifact type"
  type        = string
  default     = "NO_ARTIFACTS"
}

variable "source_type" {
  description = "Source type"
  type        = string
}

variable "build_timeout" {
  description = "Build timeout limit in minutes"
  type        = number
}

variable "environment_variables" {
  description = "Build timeout limit in minutes"
  type        = map(string)
}

variable "tags" {
  description = "Tags"
  type        = map(any)
}

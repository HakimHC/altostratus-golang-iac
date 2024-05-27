variable "name" {
  type = string
  description = "Name of the codebuild project"
}

variable "description" {
  type = string
  description = "Description of the codebuild project"
  default = null
}

variable "service_role" {
  type = string
  description = "Role ARN for the codebuild project"
}

variable "artifact_type" {
  type = string
  description = "Artifact type"
  default = "NO_ARTIFACTS"
}

variable "source_type" {
  type = string
  description = "Source type"
}

variable "build_timeout" {
  type = number
  description = "Build timeout limit in minutes"
}

variable "environment_variables" {
  type = map(string)
  description = "Build timeout limit in minutes"
}

variable "tags" {
  type = map(any)
  description = "Tags"
}

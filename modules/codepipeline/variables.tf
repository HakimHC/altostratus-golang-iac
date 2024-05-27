variable "name" {
  description = "Name of the pipeline"
  type = string
}

variable "role_arn" {
  description = "ARN of the pipeline's role"
  type = string
}

variable "artifact_bucket_name" {
  description = "Name of the S3 artifact bucket"
  type = string
}

variable "source_connection_arn" {
  description = "ARN of the CodeStarConnection of the source repository"
  type = string
}

variable "source_repository_id" {
  description = "ID of the source repository. Example: foo_user/bar_project"
  type = string
}

variable "source_branch_name" {
  description = "Name of the git branch which will trigger the pipeline"
  type = string
  default = "main"
}

variable "build_project_name" {
  description = "Name of the CodeBuild project that will be executed in the build step"
  type = string
}

variable "tags" {
  description = "Tags"
  type = map(any)
  default = null
}

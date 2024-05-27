resource "aws_codebuild_project" "this" {
  name          = var.name
  description   = var.description
  build_timeout = var.build_timeout

  service_role = var.service_role

  artifacts {
    type = var.artifact_type
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    dynamic "environment_variable" {
      for_each = var.environment_variables

      content {
        name  = environment_variable.key
        value = environment_variable.value
      }
    }
  }

  source {
    type = var.source_type
  }

  tags = var.tags
}

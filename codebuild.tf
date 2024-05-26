resource "aws_codebuild_project" "main" {
  name          = "codebuild_project"
  description   = "CodeBuild project that builds the Go API docker image and pushes it to ECR"
  build_timeout = 10

  service_role = module.codebuild_role.iam_role_arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type = "CODEPIPELINE"
  }

  tags = local.tags
}
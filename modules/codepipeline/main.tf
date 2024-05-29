locals {
  source_output = "source_output"
}

resource "aws_codepipeline" "codepipeline" {
  name     = var.name
  role_arn = var.role_arn

  artifact_store {
    location = var.artifact_bucket_name
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = [local.source_output]

      configuration = {
        ConnectionArn    = var.source_connection_arn
        FullRepositoryId = var.source_repository_id
        BranchName       = var.source_branch_name
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = [local.source_output]
      output_artifacts = [var.definition_artifact, var.image_artifact]
      version          = "1"

      configuration = {
        ProjectName = var.build_project_name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      input_artifacts = [var.definition_artifact, var.image_artifact]
      version         = "1"

      configuration = {
        ApplicationName                = var.codedeploy_application_name
        DeploymentGroupName            = var.codedeploy_deploy_group_name
        TaskDefinitionTemplateArtifact = var.definition_artifact
        TaskDefinitionTemplatePath     = var.tasdek_file_name
        AppSpecTemplateArtifact        = var.definition_artifact
        AppSpecTemplatePath            = var.appspec_file_name

        Image1ArtifactName = var.image_artifact
        Image1ContainerName = var.image_name_placeholder
      }
    }
  }

  tags = var.tags
}

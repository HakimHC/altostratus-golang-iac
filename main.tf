################################################################################
# LOCALS
################################################################################
locals {
  tags = {
    managedBy = "TERRAFORM"
    project   = var.project
  }
}

################################################################################
# CODE BUILD
################################################################################
module "codebuild" {
  source = "./modules/codebuild"

  name        = "codebuild_project"
  description = "CodeBuild project that builds the Go API docker image and pushes it to ECR"

  build_timeout = 10
  service_role  = module.roles["codebuild"].iam_role_arn

  source_type   = "CODEPIPELINE"
  artifact_type = "CODEPIPELINE"

  environment_variables = {
    ECR_REPOSITORY_URL = aws_ecr_repository.this.repository_url
  }

  tags = local.tags
}

################################################################################
# CODE PIPELINE
################################################################################
module "codepipeline" {
  source = "./modules/codepipeline"

  name                    = "deploy_pipeline_${var.project}"
  role_arn                = module.roles["codepipeline"].iam_role_arn
  artifact_bucket_name    = aws_s3_bucket.artifact_bucket.bucket
  source_connection_arn   = aws_codestarconnections_connection.this.arn
  source_repository_id    = var.source_repo_id
  source_branch_name      = "main"
  build_project_name      = module.codebuild.name

  tags = local.tags
}

################################################################################
# CODESTAR CONNECTION
################################################################################
resource "aws_codestarconnections_connection" "this" {
  name          = "${var.git_provider}-cnx-${var.project}"
  provider_type = var.git_provider

  tags = local.tags
}

################################################################################
# ECR
################################################################################
resource "aws_ecr_repository" "this" {
  name                 = "golang_api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  # TODO: Maybe enable scanning, too expensive for now

  tags = local.tags
}


################################################################################
# S3 ARTIFACT BUCKET
################################################################################
resource "aws_s3_bucket" "artifact_bucket" {
  bucket        = "artifact-bucket-${var.project}"
  force_destroy = true

  tags = local.tags
}

resource "aws_s3_bucket_public_access_block" "artifact_bucket_pab" {
  bucket = aws_s3_bucket.artifact_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}



################################################################################
# IAM POLICIES
################################################################################
data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObjectAcl",
      "s3:PutObject",
    ]

    resources = [
      aws_s3_bucket.artifact_bucket.arn,
      "${aws_s3_bucket.artifact_bucket.arn}/*"
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["codestar-connections:UseConnection"]
    resources = [aws_codestarconnections_connection.this.arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetApplication",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:RegisterApplicationRevision"
    ]

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "codebuild_policy" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObjectAcl",
      "s3:PutObject",
    ]

    resources = [
      aws_s3_bucket.artifact_bucket.arn,
      "${aws_s3_bucket.artifact_bucket.arn}/*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]

    resources = [
      aws_ecr_repository.this.arn,
      "${aws_ecr_repository.this.arn}/*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = [
      "*"
    ]
  }
}

data "aws_iam_policy_document" "codedeploy_policy" {
  statement {
    effect = "Allow"

    actions = [
      "ecs:DescribeServices",
      "ecs:CreateTaskSet",
      "ecs:UpdateServicePrimaryTaskSet",
      "ecs:DeleteTaskSet",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:ModifyRule",
      "lambda:InvokeFunction",
      "cloudwatch:DescribeAlarms",
      "sns:Publish",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObjectAcl",
      "s3:PutObject",
    ]

    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "codepipeline_policy" {
  name   = "codepipeline_policy"
  policy = data.aws_iam_policy_document.codepipeline_policy.json
}

resource "aws_iam_policy" "codebuild_policy" {
  name   = "codebuild_policy"
  policy = data.aws_iam_policy_document.codebuild_policy.json
}

resource "aws_iam_policy" "codedeploy_policy" {
  name   = "codedeploy_policy"
  policy = data.aws_iam_policy_document.codedeploy_policy.json
}

################################################################################
# IAM ROLES
################################################################################
locals {
  roles = {

    codepipeline = {
      trusted_role_services = ["codepipeline.amazonaws.com"]
      role_name = "codepipeline_role"
      custom_role_policy_arns = [aws_iam_policy.codepipeline_policy.arn]
    }

    codebuild = {
      trusted_role_services = ["codebuild.amazonaws.com"]
      role_name = "codebuild_role"
      custom_role_policy_arns = [aws_iam_policy.codebuild_policy.arn]
    }

    codedeploy = {
      trusted_role_services = ["codedeploy.amazonaws.com"]
      role_name = "codedeploy_role"
      custom_role_policy_arns = [aws_iam_policy.codedeploy_policy.arn]
    }
  }
}

module "roles" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"

  for_each = local.roles

  trusted_role_arns = []

  trusted_role_services = each.value["trusted_role_services"]

  create_role = true

  role_name         = each.value["role_name"]
  role_requires_mfa = false

  custom_role_policy_arns = each.value["custom_role_policy_arns"]
  number_of_custom_role_policy_arns = length(each.value["custom_role_policy_arns"])
}


################################################################################
# VPC
################################################################################
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "vpc-${var.project}"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a", "eu-west-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true

  tags = local.tags
}

################################################################################
# LOAD BALANCER
################################################################################
resource "aws_lb" "this" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.alb_sg.security_group_id]
  subnets            = module.vpc.private_subnets

  enable_deletion_protection = true

  tags = local.tags
}

resource "aws_lb_target_group" "blue" {
  name     = "tf-example-lb-tg-blue"
  port     = 80
  protocol = "HTTP"
  target_type = "ip"
  vpc_id   = module.vpc.vpc_id
}

resource "aws_lb_target_group" "green" {
  name     = "tf-example-lb-tg-green"
  port     = 80
  protocol = "HTTP"
  target_type = "ip"
  vpc_id   = module.vpc.vpc_id
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }
}


module "alb_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "alb-api-sg"
  description = "Security group for ALB with TCP/443 open publicly"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks      = ["0.0.0.0/0"]
  ingress_rules            = ["http-80-tcp"]

  egress_cidr_blocks      = ["0.0.0.0/0"]
  egress_rules            = ["all-all"]
}
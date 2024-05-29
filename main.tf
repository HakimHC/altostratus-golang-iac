################################################################################
# LOCALS
################################################################################
data "aws_caller_identity" "current" {}

locals {
  tags = {
    managedBy = "TERRAFORM"
    project   = var.project
  }

  account_id = data.aws_caller_identity.current.account_id

  api_container_name  = "api"
  auth_container_name = "auth"
}

locals {
  pipeline_config = {
    api = {
      # CODE BUILD
      name = local.api_container_name
      ECR_REPOSITORY_URL = aws_ecr_repository.api.repository_url

      # CODE DEPLOY
      target_groups = [
        aws_lb_target_group.blue_green_tg_1.name,
        aws_lb_target_group.blue_green_tg_2.name
      ]
      service = aws_ecs_service.api.name

      # CODE PIPELINE
      source_repository_id = var.api_source_repo_id
    }

    auth = {
      # CODE BUILD
      name = local.auth_container_name
      ECR_REPOSITORY_URL = aws_ecr_repository.auth.repository_url

      # CODE DEPLOY
      target_groups = [
        aws_lb_target_group.blue_green_tg_3.name,
        aws_lb_target_group.blue_green_tg_4.name
      ]
      service = aws_ecs_service.auth.name

      # CODE PIPELINE
      source_repository_id = var.auth_source_repo_id
    }
  }
}

################################################################################
# CODE BUILD
################################################################################
module "codebuild" {
  source = "./modules/codebuild"

  for_each = local.pipeline_config

  name        = "${each.value["name"]}_codebuild_project"
  description = "CodeBuild project that builds the docker images and pushes it to ECR"

  build_timeout = 10
  service_role  = module.roles["codebuild"].iam_role_arn

  source_type   = "CODEPIPELINE"
  artifact_type = "CODEPIPELINE"

  environment_variables = {
    ECR_REPOSITORY_URL = each.value["ECR_REPOSITORY_URL"]
  }

  tags = local.tags
}


################################################################################
# CODE DEPLOY
################################################################################
module "codedeploy" {
  source = "./modules/ecs_deploy"

  for_each = local.pipeline_config

  app_name               = "${each.value["name"]}_service_deploy_app"
  deployment_group_name  = "${each.value["name"]}_service_deployment_group"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  service_role_arn = module.roles["codedeploy"].iam_role_arn

  ecs_cluster_name = aws_ecs_cluster.this.name
  ecs_service_name = each.value["service"]

  prod_listener_arn = aws_lb_listener.this.arn
  target_groups = each.value["target_groups"]
}

################################################################################
# CODE PIPELINE
################################################################################
module "codepipeline" {
  source = "./modules/codepipeline"

  for_each = local.pipeline_config

  name                  = "${each.value["name"]}_deploy_pipeline"
  role_arn              = module.roles["codepipeline"].iam_role_arn
  artifact_bucket_name  = aws_s3_bucket.artifact_bucket.bucket
  source_connection_arn = aws_codestarconnections_connection.this.arn
  source_repository_id = each.value["source_repository_id"]
  source_branch_name   = "main"
  build_project_name   = module.codebuild[each.key].name

  codedeploy_application_name  = module.codedeploy[each.key].application_name
  codedeploy_deploy_group_name = module.codedeploy[each.key].deployment_group_name

  definition_artifact    = "DefinitionArtifact"
  image_artifact         = "ImageArtifact"
  image_name_placeholder = "IMAGE1_NAME"

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
resource "aws_ecr_repository" "api" {
  name                 = "${local.api_container_name}_img"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = local.tags
}

resource "aws_ecr_repository" "auth" {
  name                 = "${local.auth_container_name}_img"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

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
  name               = "alb-main"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.alb_sg.security_group_id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  tags = local.tags
}

# TODO: do for each to create resources dynamically

locals {
  target_group_mapping = ["api", "api", "auth", "auth"]
}

#resource "aws_lb_target_group" "target_groups" {
#  count = length(local.target_group_mapping)
#
#  name        = "${local.target_group_mapping[count.index]}-tg-${((count.index + 1) % 2) + 1}"
#  port        = 80
#  protocol    = "HTTP"
#  target_type = "ip"
#  vpc_id      = module.vpc.vpc_id
#
#  deregistration_delay = "5"
#}

resource "aws_lb_target_group" "blue_green_tg_1" {
  name        = "blue-green-tg-1"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  deregistration_delay = "5"
}

resource "aws_lb_target_group" "blue_green_tg_2" {
  name        = "blue-green-tg-2"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  deregistration_delay = "5"
}

resource "aws_lb_target_group" "blue_green_tg_3" {
  name        = "blue-green-tg-3"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  deregistration_delay = "5"
}

resource "aws_lb_target_group" "blue_green_tg_4" {
  name        = "blue-green-tg-4"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  deregistration_delay = "5"
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue_green_tg_1.arn
  }

  lifecycle {
    ignore_changes = [default_action[0].target_group_arn]
  }
}

resource "aws_lb_listener_rule" "auth" {
  listener_arn = aws_lb_listener.this.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue_green_tg_3.arn
  }

  condition {
    path_pattern {
      values = ["/api/auth/*"]
    }
  }
}

################################################################################
# SECURITY GROUPS
################################################################################
module "alb_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "alb-sg"
  description = "Security group for ALB with TCP/80 open publicly"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "http-8080-tcp"]

  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["all-all"]
}

module "ecs_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "ecs-sg"
  description = "Security group for ECS service with TCP/80 open publicly"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "http-8080-tcp"]

  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["all-all"]
}

################################################################################
# ECS
################################################################################
resource "aws_ecs_cluster" "this" {
  name = "go_api_cluster"

  tags = local.tags
}

resource "aws_ecs_cluster_capacity_providers" "example" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 70
    capacity_provider = "FARGATE"
  }

  default_capacity_provider_strategy {
    weight            = 30
    capacity_provider = "FARGATE_SPOT"
  }
}

locals {
  task_def_containers = {
    api = local.api_container_name,
    auth = local.auth_container_name
  }
}

resource "aws_ecs_task_definition" "template" {
  for_each = local.task_def_containers

  family                   = each.value
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "arn:aws:iam::${local.account_id}:role/ecsTaskExecutionRole"

  container_definitions = jsonencode([
    {
      name      = each.value
      image     = "nginx"
      essential = true

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# TODO: for each
resource "aws_ecs_service" "api" {
  name            = "${local.api_container_name}_service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.template["api"].arn
  desired_count   = 3
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.blue_green_tg_1.arn
    container_name   = local.api_container_name
    container_port   = 80
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [module.ecs_sg.security_group_id]
    assign_public_ip = false
  }

  scheduling_strategy = "REPLICA"

  lifecycle {
    ignore_changes = [
      task_definition,
      load_balancer
    ]
  }
}

resource "aws_ecs_service" "auth" {
  name            = "${local.auth_container_name}_service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.template["auth"].arn
  desired_count   = 3
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.blue_green_tg_3.arn
    container_name   = local.auth_container_name
    container_port   = 80
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [module.ecs_sg.security_group_id]
    assign_public_ip = false
  }

  scheduling_strategy = "REPLICA"

  lifecycle {
    ignore_changes = [
      task_definition,
      load_balancer
    ]
  }
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
      "codedeploy:RegisterApplicationRevision",
      "codedeploy:GetApplicationRevision"
    ]

    resources = ["*"]
  }

  statement {
    effect = "Allow"

    actions = [
      "ecs:RegisterTaskDefinition",
      "iam:PassRole"
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
      "*"
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
      "iam:PassRole"
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
      trusted_role_services   = ["codepipeline.amazonaws.com"]
      role_name               = "codepipeline_role"
      custom_role_policy_arns = [aws_iam_policy.codepipeline_policy.arn]
    }

    codebuild = {
      trusted_role_services   = ["codebuild.amazonaws.com"]
      role_name               = "codebuild_role"
      custom_role_policy_arns = [aws_iam_policy.codebuild_policy.arn]
    }

    codedeploy = {
      trusted_role_services   = ["codedeploy.amazonaws.com"]
      role_name               = "codedeploy_role"
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

  custom_role_policy_arns           = each.value["custom_role_policy_arns"]
  number_of_custom_role_policy_arns = length(each.value["custom_role_policy_arns"])
}


#######################
#module "alb" {
#  source = "terraform-aws-modules/alb/aws"
#
#  name    = "my-alb-test"
#  vpc_id  = module.vpc.vpc_id
#  subnets = module.vpc.public_subnets
#
#  # Security Group
#  security_group_ingress_rules = {
#    all_http = {
#      from_port   = 80
#      to_port     = 80
#      ip_protocol = "tcp"
#      description = "HTTP web traffic"
#      cidr_ipv4   = "0.0.0.0/0"
#    }
#    all_https = {
#      from_port   = 443
#      to_port     = 443
#      ip_protocol = "tcp"
#      description = "HTTPS web traffic"
#      cidr_ipv4   = "0.0.0.0/0"
#    }
#  }
#  security_group_egress_rules = {
#    all = {
#      ip_protocol = "-1"
#      cidr_ipv4   = "0.0.0.0/0"
#    }
#  }
#
#  listeners = {
#    test-listener = {
#      port     = 80
#      protocol = "HTTP"
#
#      forward = {
#        target_group_key = "tg1"
#      }
#    }
#  }
#
#  target_groups = {
#    tg1 = {
#      name_prefix      = "tg"
#      protocol         = "HTTP"
#      port             = 80
#      target_type      = "ip"
#      create_attachment = false
#    }
#  }
#
#  tags = local.tags
#}
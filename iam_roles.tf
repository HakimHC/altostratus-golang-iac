module "codepipeline_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"

  trusted_role_arns = []

  trusted_role_services = [
    "codepipeline.amazonaws.com"
  ]

  create_role = true

  role_name         = "codepipeline_role"
  role_requires_mfa = false

  custom_role_policy_arns = [
    aws_iam_policy.codepipeline_policy.arn
  ]
  number_of_custom_role_policy_arns = 1
}

module "codebuild_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"

  trusted_role_arns = []

  trusted_role_services = [
    "codebuild.amazonaws.com"
  ]

  create_role = true

  role_name         = "codebuild_role"
  role_requires_mfa = false

  custom_role_policy_arns = [
    aws_iam_policy.codebuild_policy.arn
  ]
  number_of_custom_role_policy_arns = 1
}

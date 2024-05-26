resource "aws_ecr_repository" "main" {
  name                 = "ecr-main-${var.project}"
  image_tag_mutability = "MUTABLE"

  tags = local.tags

  # TODO: Maybe enable scanning, too expensive for now
  #  image_scanning_configuration {
  #    scan_on_push = true
  #  }
}

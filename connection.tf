resource "aws_codestarconnections_connection" "github" {
  name          = "github-cnx"
  provider_type = "GitHub"

  tags = local.tags
}
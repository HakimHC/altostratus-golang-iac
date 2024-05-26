resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "codepipeline-bucket-${var.project}"

  tags = local.tags
}

resource "aws_s3_bucket_public_access_block" "codepipeline_bucket_pab" {
  bucket = aws_s3_bucket.codepipeline_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

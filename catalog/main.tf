# The installers catalog - the durable layer. It outlives every workstation,
# so it lives in its own root and a workstation destroy never touches it.
# Terraform creates the bucket; scripts/upload-catalog.ps1 fills it.

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "catalog" {
  # The account ID keeps the name globally unique without hardcoding it.
  bucket = "${var.project}-catalog-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "catalog" {
  bucket = aws_s3_bucket.catalog.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "catalog" {
  bucket = aws_s3_bucket.catalog.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# An installer overwritten by mistake can be recovered.
resource "aws_s3_bucket_versioning" "catalog" {
  bucket = aws_s3_bucket.catalog.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "catalog" {
  bucket = aws_s3_bucket.catalog.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.catalog.arn, "${aws_s3_bucket.catalog.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      }
    ]
  })

  # Public access block first: S3 then refuses any policy that would be public.
  depends_on = [aws_s3_bucket_public_access_block.catalog]
}

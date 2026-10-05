# Workstations reach AWS through an instance profile: short-lived
# credentials delivered by AWS, no access key stored on the machine.

resource "aws_iam_role" "workstation" {
  name = "${var.project}-workstation"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "catalog_read" {
  name = "catalog-read"
  role = aws_iam_role.workstation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadInstallers"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${data.aws_s3_bucket.catalog.arn}/apps/*"
      },
      {
        # Without ListBucket a missing file answers AccessDenied, not NotFound.
        Sid       = "ListInstallers"
        Effect    = "Allow"
        Action    = "s3:ListBucket"
        Resource  = data.aws_s3_bucket.catalog.arn
        Condition = { StringLike = { "s3:prefix" = ["apps/*"] } }
      }
    ]
  })
}

# Session Manager: a shell and RDP port forwarding with no open port.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.workstation.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "workstation" {
  name = "${var.project}-workstation"
  role = aws_iam_role.workstation.name
}

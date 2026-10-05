data "aws_s3_bucket" "catalog" {
  bucket = var.catalog_bucket
}

# Stops the plan if an installer some workstation needs is missing from the
# catalog, instead of a workstation failing halfway through its boot.
# Lists names only: nothing is downloaded here.
data "aws_s3_objects" "catalog" {
  bucket = var.catalog_bucket
  prefix = "apps/"

  lifecycle {
    postcondition {
      condition     = alltrue([for k in local.requested_installers : contains(self.keys, k)])
      error_message = "Missing in s3://${var.catalog_bucket}: ${join(", ", [for k in local.requested_installers : k if !contains(self.keys, k)])}. Upload them with scripts/upload-catalog.ps1."
    }
  }
}

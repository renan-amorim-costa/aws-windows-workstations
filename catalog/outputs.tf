output "bucket" {
  description = "Catalog bucket name. Pass it as catalog_bucket to the workstations layer."
  value       = aws_s3_bucket.catalog.id
}

variable "project" {
  description = "Name prefix for every resource."
  type        = string
  default     = "workstations"
}

variable "aws_region" {
  description = "AWS region for the catalog bucket. Must match the workstations layer."
  type        = string
  default     = "sa-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile. Leave null to use environment credentials (CI, OIDC)."
  type        = string
  default     = null
}

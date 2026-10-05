variable "project" {
  description = "Name prefix for every resource."
  type        = string
  default     = "workstations"
}

variable "environment" {
  description = "Logical environment, used in tags."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "stg", "prd"], var.environment)
    error_message = "Use dev, stg or prd."
  }
}

variable "aws_region" {
  description = "AWS region. Must match the catalog layer."
  type        = string
  default     = "sa-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile. Leave null to use environment credentials (CI, OIDC)."
  type        = string
  default     = null
}

variable "catalog_bucket" {
  description = "Installers bucket: the bucket output of the catalog layer."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC address range."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Subnet for the workstations."
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidrs" {
  description = "Database subnets, keyed by AZ suffix. RDS requires at least two AZs."
  type        = map(string)
  default = {
    a = "10.0.10.0/24"
    b = "10.0.11.0/24"
  }
}

variable "internal_domain" {
  description = "Private DNS zone that gives each database a stable name."
  type        = string
  default     = "lab.internal"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "instance_type" {
  description = "Workstation size. Windows with a browser and DBeaver needs 4 GB."
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Existing EC2 key pair, used to decrypt the Administrator password."
  type        = string
}

variable "admin_cidrs" {
  description = "Networks allowed to reach RDP and the status page. Empty opens no inbound port: connect through SSM."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.admin_cidrs : can(cidrhost(c, 0))])
    error_message = "Each entry must be a CIDR, for example 203.0.113.10/32."
  }
}

variable "workstations" {
  description = <<-EOT
    One Windows workstation per entry; the key names it.
      apps      = app => version, from local.app_catalog
      databases = engines it needs: mysql, sqlserver, postgres
    Databases are created from these lists: if nobody asks for postgres,
    no postgres is created.
  EOT

  type = map(object({
    apps      = map(string)
    databases = optional(list(string), [])
  }))

  default = {}

  validation {
    condition     = alltrue(flatten([for w in var.workstations : [for app in keys(w.apps) : contains(keys(local.app_catalog), app)]]))
    error_message = "Unknown app. Available: ${join(", ", sort(keys(local.app_catalog)))}."
  }

  validation {
    condition     = alltrue(flatten([for w in var.workstations : [for db in w.databases : contains(keys(local.db_engines), db)]]))
    error_message = "Unknown database engine. Available: ${join(", ", sort(keys(local.db_engines)))}."
  }
}

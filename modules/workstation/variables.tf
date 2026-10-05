variable "name" {
  description = "Workstation name, used in resource names and tags."
  type        = string
}

variable "ami_id" {
  description = "Windows AMI."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "vpc_id" {
  description = "VPC for the workstation security group."
  type        = string
}

variable "subnet_id" {
  description = "Subnet for the instance."
  type        = string
}

variable "instance_profile" {
  description = "Instance profile granting catalog read and Session Manager."
  type        = string
}

variable "key_name" {
  description = "EC2 key pair that encrypts the Administrator password."
  type        = string
}

variable "admin_cidrs" {
  description = "Networks allowed to reach RDP and the status page. Empty opens no inbound port."
  type        = list(string)
}

variable "aws_region" {
  description = "Region of the catalog bucket and of the helper commands."
  type        = string
}

variable "cli_profile" {
  description = "AWS CLI profile shown in the helper commands. Null omits it."
  type        = string
  default     = null
}

variable "catalog_bucket" {
  description = "Bucket holding the installers."
  type        = string
}

variable "apps" {
  description = "Apps to install, in order. key = installer path in the catalog bucket."
  type = list(object({
    name     = string
    version  = string
    key      = string
    type     = string
    args     = list(string)
    registry = string
  }))

  validation {
    condition     = alltrue([for a in var.apps : contains(["msi", "nsis", "inno", "webview2"], a.type)])
    error_message = "Installer types: msi, nsis, inno, webview2."
  }
}

variable "databases" {
  description = "Databases this workstation reaches, keyed by engine: host, port and database name."
  type = map(object({
    host     = string
    port     = number
    database = string
  }))
  default = {}
}

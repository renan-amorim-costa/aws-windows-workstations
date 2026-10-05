data "aws_ami" "windows" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}

module "workstation" {
  source   = "../modules/workstation"
  for_each = var.workstations

  name             = "${var.project}-${each.key}"
  ami_id           = data.aws_ami.windows.id
  instance_type    = var.instance_type
  vpc_id           = aws_vpc.main.id
  subnet_id        = aws_subnet.public.id
  instance_profile = aws_iam_instance_profile.workstation.name
  key_name         = var.key_name
  admin_cidrs      = var.admin_cidrs
  aws_region       = var.aws_region
  cli_profile      = var.aws_profile
  catalog_bucket   = var.catalog_bucket
  apps             = local.workstation_apps[each.key]

  # Only the databases this workstation asked for, by their stable name.
  databases = {
    for db in each.value.databases : db => {
      host     = aws_route53_record.database[db].fqdn
      port     = local.db_engines[db].port
      database = coalesce(local.db_engines[db].default_db, "master")
    }
  }

  # Workstations are created only after the catalog check passed.
  depends_on = [data.aws_s3_objects.catalog]
}

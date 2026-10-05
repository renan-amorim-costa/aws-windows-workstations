locals {
  # Silent-install flags per installer family.
  silent_flags = {
    msi      = ["/quiet", "/norestart"]
    nsis     = ["/S"]
    inno     = ["/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-"]
    webview2 = ["/silent", "/install"]
  }

  # Each app with its full argument list, quoted for PowerShell.
  installs = [for a in var.apps : {
    label    = "${a.name} ${a.version}"
    key      = a.key
    registry = a.registry
    args     = join(", ", [for arg in concat(local.silent_flags[a.type], a.args) : "\"${arg}\""])
  }]

  configure_dbeaver = contains([for a in var.apps : a.name], "dbeaver")

  # DBeaver's data-sources.json for this workstation's databases. No
  # credentials: each user types them once and DBeaver keeps them.
  # The mysql and sqlserver entries follow a working DBeaver config; postgres
  # uses DBeaver's own driver id and has not been verified end to end yet.
  dbeaver_drivers = {
    mysql     = { provider = "mysql", driver = "mysql8", auth = "native" }
    sqlserver = { provider = "sqlserver", driver = "microsoft", auth = "sqlserver_database" }
    postgres  = { provider = "postgresql", driver = "postgres-jdbc", auth = "native" }
  }

  dbeaver_config = jsonencode({
    folders = {}
    connections = {
      for engine, db in var.databases : engine => {
        provider = local.dbeaver_drivers[engine].provider
        driver   = local.dbeaver_drivers[engine].driver
        name     = engine
        configuration = {
          host     = db.host
          port     = tostring(db.port)
          database = db.database
          url = {
            mysql     = "jdbc:mysql://${db.host}:${db.port}/${db.database}"
            sqlserver = "jdbc:sqlserver://;serverName=${db.host};port=${db.port};databaseName=${db.database}"
            postgres  = "jdbc:postgresql://${db.host}:${db.port}/${db.database}"
          }[engine]
          configurationType = "MANUAL"
          type              = "dev"
          "auth-model"      = local.dbeaver_drivers[engine].auth
        }
      }
    }
  })

  profile_flag = var.cli_profile == null ? "" : " --profile ${var.cli_profile}"
}

resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "Workstation ${var.name}"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = length(var.admin_cidrs) > 0 ? { rdp = 3389, status-page = 80 } : {}

    content {
      description = "${ingress.key} from admin networks"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = var.admin_cidrs
    }
  }

  # Outbound open: Windows Update, app updates and DBeaver's JDBC drivers.
  #trivy:ignore:aws-ec2-no-public-egress-sgr
  egress {
    description = "Outbound to the internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-sg" }
}

resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.this.id]
  iam_instance_profile   = var.instance_profile
  key_name               = var.key_name

  # IMDSv2 only: blocks credential theft through forged metadata requests.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/boot.ps1.tftpl", {
    name               = var.name
    bucket             = var.catalog_bucket
    region             = var.aws_region
    installs           = local.installs
    databases          = var.databases
    configure_dbeaver  = local.configure_dbeaver
    dbeaver_config_b64 = base64encode(local.dbeaver_config)
  })

  # The script runs only on first boot: without this a change would never apply.
  user_data_replace_on_change = true

  # A newer Windows image must not replace a running workstation.
  lifecycle {
    ignore_changes = [ami]
  }

  tags = { Name = var.name }
}

# Access by security group reference, not by IP range: a database accepts
# connections only from the workstations that asked for it. New
# workstations get access without touching the database rule, and a machine
# without that security group cannot connect, even from the same subnet.

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db"
  subnet_ids = [for s in aws_subnet.private : s.id]
}

resource "aws_security_group" "database" {
  name = "${var.project}-database"
  # A description change forces replacement of the security group: keep it stable.
  description = "Databases - accepts only the workstations that use them"
  vpc_id      = aws_vpc.main.id

  # Inbound rules are separate resources (below): inline and separate rules
  # on the same group fight over each other on every plan.
  # No egress: databases only answer.

  tags = { Name = "${var.project}-database" }
}

resource "aws_db_instance" "main" {
  for_each = local.requested_engines

  identifier     = "${var.project}-${each.key}"
  engine         = local.db_engines[each.key].engine
  engine_version = local.db_engines[each.key].version
  instance_class = var.db_instance_class
  port           = local.db_engines[each.key].port

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = local.db_engines[each.key].default_db
  username = local.db_engines[each.key].master_user

  # RDS generates the password and keeps it in Secrets Manager: it never
  # passes through tfvars or the Terraform state.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  publicly_accessible    = false
  multi_az               = false

  # Disposable environment, rebuilt from code in minutes: no final snapshot.
  skip_final_snapshot = true

  tags = { Name = "${var.project}-${each.key}" }
}

# One rule per workstation and database it asked for. A separate resource,
# not an inline block: inline, the graph would be a cycle (database security
# group -> workstations -> database instance -> database security group).
resource "aws_vpc_security_group_ingress_rule" "database" {
  for_each = {
    for pair in flatten([
      for name, w in var.workstations : [
        for db in w.databases : { workstation = name, engine = db }
      ]
    ]) : "${pair.workstation}-${pair.engine}" => pair
  }

  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = module.workstation[each.value.workstation].security_group_id
  from_port                    = local.db_engines[each.value.engine].port
  to_port                      = local.db_engines[each.value.engine].port
  ip_protocol                  = "tcp"
  description                  = "${each.value.engine} from workstation ${each.value.workstation}"
}

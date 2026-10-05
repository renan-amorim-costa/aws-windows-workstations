output "workstations" {
  description = "Per workstation: instance, how to get the password, and how to connect."
  value = {
    for name, w in module.workstation : name => {
      instance_id    = w.instance_id
      public_ip      = w.public_ip
      admin_password = w.admin_password_command
      rdp_over_ssm   = w.rdp_over_ssm_command
    }
  }
}

output "databases" {
  description = "Per engine: stable host name, port, user, and the secret holding the password."
  value = {
    for engine, db in aws_db_instance.main : engine => {
      host            = aws_route53_record.database[engine].fqdn
      port            = db.port
      username        = db.username
      password_secret = db.master_user_secret[0].secret_arn
    }
  }
}

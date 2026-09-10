locals {
  # Npgsql reject connections with no RDS CA bundle installed in the container's trust store.
  ssl_suffix = var.force_ssl ? ";SSL Mode=Require;Trust Server Certificate=true" : ""

  connection_string = join("", [
    "Host=${aws_db_instance.this.address}",
    ";Port=${aws_db_instance.this.port}",
    ";Database=${var.db_name}",
    ";Username=${var.username}",
    ";Password=${random_password.master.result}",
    local.ssl_suffix,
  ])
}

resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = var.name
  }
}

resource "aws_security_group" "this" {
  name        = "${var.name}-rds"
  description = "Postgres access for ${var.name}"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-rds"
  }
}

resource "aws_vpc_security_group_ingress_rule" "postgres" {
  for_each = var.allowed_security_group_ids

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Postgres from ${each.key}"
}

# EF Core InitialCreate migration will "CREATE EXTENSION postgis".
resource "aws_db_parameter_group" "this" {
  name   = var.name
  family = "postgres${split(".", var.engine_version)[0]}"

  parameter {
    name         = "rds.force_ssl"
    value        = var.force_ssl ? "1" : "0"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "random_password" "master" {
  length  = 32
  special = true
  # RDS forbids / @ " and space in master passwords.
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "this" {
  identifier = var.name

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage == var.allocated_storage ? null : var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.username
  password = random_password.master.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false

  multi_az                     = var.multi_az
  backup_retention_period      = var.backup_retention_period
  backup_window                = "02:00-03:00"
  maintenance_window           = "sun:03:30-sun:04:30"
  auto_minor_version_upgrade   = true
  performance_insights_enabled = var.performance_insights_enabled

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  lifecycle {
    # final_snapshot_identifier contains timestamp()
    # Actual password on the RDS instance is stored in AWS
    ignore_changes = [final_snapshot_identifier, password]
  }

  tags = {
    Name = var.name
  }
}

# ---------------------------------------------------------------------------
# Credentials
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "db" {
  name        = "${var.name}/database"
  description = "Postgres credentials and connection string for ${var.name}"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    POSTGRES_DB                          = var.db_name
    POSTGRES_USER                        = var.username
    POSTGRES_PASSWORD                    = random_password.master.result
    ConnectionStrings__DefaultConnection = local.connection_string
    host                                 = aws_db_instance.this.address
    port                                 = aws_db_instance.this.port
  })
}

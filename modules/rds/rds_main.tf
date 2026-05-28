########################################################################
# RDS Module
# Creates: DB subnet groups, security groups, MySQL + PostgreSQL RDS,
#          Secrets Manager secrets for credentials
########################################################################

resource "random_password" "mysql" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "postgres" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ── Secrets Manager ───────────────────────────────────────────────────
resource "aws_secretsmanager_secret" "mysql" {
  name                    = "project-bedrock/rds/mysql"
  description             = "MySQL RDS credentials for Project Bedrock catalog service"
  recovery_window_in_days = 7

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "mysql" {
  secret_id = aws_secretsmanager_secret.mysql.id
  secret_string = jsonencode({
    username = var.mysql_username
    password = random_password.mysql.result
    engine   = "mysql"
    host     = aws_db_instance.mysql.address
    port     = 3306
    dbname   = var.mysql_db_name
  })
}

resource "aws_secretsmanager_secret" "postgres" {
  name                    = "project-bedrock/rds/postgres"
  description             = "PostgreSQL RDS credentials for Project Bedrock orders service"
  recovery_window_in_days = 7

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "postgres" {
  secret_id = aws_secretsmanager_secret.postgres.id
  secret_string = jsonencode({
    username = var.postgres_username
    password = random_password.postgres.result
    engine   = "postgres"
    host     = aws_db_instance.postgres.address
    port     = 5432
    dbname   = var.postgres_db_name
  })
}

# ── Security Groups ───────────────────────────────────────────────────
resource "aws_security_group" "mysql" {
  name        = "project-bedrock-mysql-sg"
  description = "Allow MySQL traffic from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.node_security_group_id]
    description     = "MySQL from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(var.common_tags, {
    Name = "project-bedrock-mysql-sg"
  })
}

resource "aws_security_group" "postgres" {
  name        = "project-bedrock-postgres-sg"
  description = "Allow PostgreSQL traffic from EKS nodes only"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.node_security_group_id]
    description     = "PostgreSQL from EKS nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(var.common_tags, {
    Name = "project-bedrock-postgres-sg"
  })
}

# ── DB Subnet Group (private subnets only) ────────────────────────────
resource "aws_db_subnet_group" "main" {
  name        = "project-bedrock-db-subnet-group"
  description = "Private subnets for Project Bedrock RDS instances"
  subnet_ids  = var.private_subnet_ids

  tags = merge(var.common_tags, {
    Name = "project-bedrock-db-subnet-group"
  })
}

# ── MySQL RDS Instance ────────────────────────────────────────────────
resource "aws_db_instance" "mysql" {
  identifier        = "project-bedrock-mysql"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = var.rds_instance_class
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.mysql_db_name
  username = var.mysql_username
  password = random_password.mysql.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.mysql.id]

  multi_az               = false   # set true for production HA
  publicly_accessible    = false
  skip_final_snapshot    = false
  final_snapshot_identifier = "project-bedrock-mysql-final-snapshot"
  deletion_protection    = false   # set true for production

  backup_retention_period = 7
  backup_window           = "02:00-03:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  parameter_group_name = aws_db_parameter_group.mysql.name

  tags = merge(var.common_tags, {
    Name = "project-bedrock-mysql"
  })
}

resource "aws_db_parameter_group" "mysql" {
  name   = "project-bedrock-mysql8"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  tags = var.common_tags
}

# ── PostgreSQL RDS Instance ───────────────────────────────────────────
resource "aws_db_instance" "postgres" {
  identifier        = "project-bedrock-postgres"
  engine            = "postgres"
  engine_version    = "16.3"
  instance_class    = var.rds_instance_class
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.postgres_db_name
  username = var.postgres_username
  password = random_password.postgres.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.postgres.id]

  multi_az               = false
  publicly_accessible    = false
  skip_final_snapshot    = false
  final_snapshot_identifier = "project-bedrock-postgres-final-snapshot"
  deletion_protection    = false

  backup_retention_period = 7
  backup_window           = "02:00-03:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  tags = merge(var.common_tags, {
    Name = "project-bedrock-postgres"
  })
}

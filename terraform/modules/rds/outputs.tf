output "mysql_endpoint" {
  description = "MySQL RDS endpoint (host:port)"
  value       = "${aws_db_instance.mysql.address}:3306"
}

output "mysql_address" {
  description = "MySQL RDS hostname"
  value       = aws_db_instance.mysql.address
}

output "mysql_secret_arn" {
  description = "ARN of the MySQL credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.mysql.arn
}

output "postgres_endpoint" {
  description = "PostgreSQL RDS endpoint (host:port)"
  value       = "${aws_db_instance.postgres.address}:5432"
}

output "postgres_address" {
  description = "PostgreSQL RDS hostname"
  value       = aws_db_instance.postgres.address
}

output "postgres_secret_arn" {
  description = "ARN of the PostgreSQL credentials secret in Secrets Manager"
  value       = aws_secretsmanager_secret.postgres.arn
}

output "mysql_security_group_id" {
  value = aws_security_group.mysql.id
}

output "postgres_security_group_id" {
  value = aws_security_group.postgres.id
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "node_security_group_id" {
  type = string
}

variable "mysql_db_name" {
  type = string
}

variable "mysql_username" {
  type = string
}

variable "postgres_db_name" {
  type = string
}

variable "postgres_username" {
  type = string
}

variable "rds_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "common_tags" {
  type = map(string)
}

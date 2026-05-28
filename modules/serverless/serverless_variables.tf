variable "student_id" {
  type = string
}

variable "dev_user_arn" {
  type = string
}

variable "lambda_execution_role" {
  type = string
}

variable "common_tags" {
  type = map(string)
}

output "dev_user_name" {
  value = aws_iam_user.dev_view.name
}

output "dev_user_arn" {
  value = aws_iam_user.dev_view.arn
}

output "dev_user_access_key_id" {
  value     = aws_iam_access_key.dev_view.id
  sensitive = true
}

output "dev_user_secret_access_key" {
  value     = aws_iam_access_key.dev_view.secret
  sensitive = true
}

output "dev_user_console_password" {
  value     = aws_iam_user_login_profile.dev_view.password
  sensitive = true
}

output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller.arn
}

output "cart_service_role_arn" {
  value = aws_iam_role.cart_service.arn
}

output "lambda_execution_role_arn" {
  value = aws_iam_role.lambda_exec.arn
}

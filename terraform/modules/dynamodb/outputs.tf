output "cart_table_name" {
  value = aws_dynamodb_table.cart.name
}

output "cart_table_arn" {
  value = aws_dynamodb_table.cart.arn
}

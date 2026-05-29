# DynamoDB Module

resource "aws_dynamodb_table" "cart" {
  name         = var.cart_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "customerId"
  range_key    = "itemId"

  attribute {
    name = "customerId"
    type = "S"
  }

  attribute {
    name = "itemId"
    type = "S"
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.common_tags, {
    Name = var.cart_table_name
  })
}

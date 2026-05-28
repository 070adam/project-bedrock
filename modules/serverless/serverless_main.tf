########################################################################
# Serverless Module
# Creates: S3 assets bucket, Lambda function, S3 event notification
########################################################################

# ── Lambda source package ─────────────────────────────────────────────
data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# ── CloudWatch Log Group for Lambda ──────────────────────────────────
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/bedrock-asset-processor"
  retention_in_days = 30

  tags = var.common_tags
}

# ── Lambda Function ───────────────────────────────────────────────────
resource "aws_lambda_function" "asset_processor" {
  function_name = "bedrock-asset-processor"
  description   = "Logs uploaded asset filenames from the bedrock-assets S3 bucket"

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "python3.12"
  handler          = "lambda_function.handler"
  role             = var.lambda_execution_role
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  tags = var.common_tags

  depends_on = [aws_cloudwatch_log_group.lambda]
}

# ── S3 Assets Bucket ──────────────────────────────────────────────────
resource "aws_s3_bucket" "assets" {
  bucket        = "bedrock-assets-${var.student_id}"
  force_destroy = true

  tags = merge(var.common_tags, {
    Name = "bedrock-assets-${var.student_id}"
  })
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# ── Lambda Permission — allow S3 to invoke it ─────────────────────────
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.asset_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.assets.arn
}

# ── S3 Event Notification → Lambda ───────────────────────────────────
resource "aws_s3_bucket_notification" "asset_upload" {
  bucket = aws_s3_bucket.assets.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.asset_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

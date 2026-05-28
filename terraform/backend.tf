# Remote state backend — S3 only (DynamoDB locking not required per spec).
# Before running terraform init, create the bucket manually or via bootstrap script:
#   ./scripts/bootstrap-backend.sh
#
# Replace <YOUR-STUDENT-ID> in the bucket name below before initialising.

terraform {
  backend "s3" {
    bucket       = "project-bedrock-tfstate-ALT/SOE/025/3914"
    key          = "project-bedrock/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true

  }
}

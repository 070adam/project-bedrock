terraform {
  backend "s3" {
    bucket  = "bedrock-state-alt-soe-025-3914"
    key     = "project-bedrock/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

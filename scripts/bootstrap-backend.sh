#!/usr/bin/env bash
# bootstrap-backend.sh
# Creates the S3 bucket used for Terraform remote state.
# Run this ONCE before `terraform init`.
#
# Usage:
#   chmod +x scripts/bootstrap-backend.sh
#   STUDENT_ID=your-id ./scripts/bootstrap-backend.sh

set -euo pipefail

STUDENT_ID="${STUDENT_ID:?'ERROR: Set STUDENT_ID env variable before running this script.'}"
BUCKET_NAME="project-bedrock-tfstate-${STUDENT_ID}"
REGION="us-east-1"

echo "==> Creating Terraform state bucket: ${BUCKET_NAME}"

# Create the bucket
aws s3api create-bucket \
  --bucket "${BUCKET_NAME}" \
  --region "${REGION}" \
  --create-bucket-configuration LocationConstraint="${REGION}" 2>/dev/null || {
    # us-east-1 does NOT accept LocationConstraint
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${REGION}"
  }

echo "==> Enabling versioning on ${BUCKET_NAME}"
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

echo "==> Enabling server-side encryption on ${BUCKET_NAME}"
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

echo "==> Blocking all public access on ${BUCKET_NAME}"
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "==> Tagging bucket"
aws s3api put-bucket-tagging \
  --bucket "${BUCKET_NAME}" \
  --tagging 'TagSet=[{Key=Project,Value=karatu-2025-capstone}]'

echo ""
echo "✅ Backend bucket ready: s3://${BUCKET_NAME}"
echo ""
echo "Next steps:"
echo "  1. Update terraform/backend.tf — replace <YOUR-STUDENT-ID> with: ${STUDENT_ID}"
echo "  2. Run: cd terraform && terraform init"
echo "  3. Run: terraform plan -var='student_id=${STUDENT_ID}'"

#!/usr/bin/env bash
# setup-backend.sh — Bootstrap the S3 + DynamoDB Terraform remote state backend.
# Run this ONCE per AWS account before running `terraform init` for the first time.
#
# Usage:
#   AWS_REGION=us-west-2 \
#   BUCKET_NAME=my-org-terraform-state \
#   DYNAMO_TABLE=my-org-terraform-locks \
#   bash scripts/setup-backend.sh

set -euo pipefail

REGION="${AWS_REGION:-us-west-2}"
BUCKET="${BUCKET_NAME:-my-terraform-state-bucket-name}"
DYNAMO_TABLE="${DYNAMO_TABLE:-my-lock-table}"

echo "==> Creating S3 state bucket: ${BUCKET} in ${REGION}"

if aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "    Bucket already exists, skipping creation."
else
  if [ "${REGION}" = "us-east-1" ]; then
    aws s3api create-bucket \
      --bucket "${BUCKET}" \
      --region "${REGION}"
  else
    aws s3api create-bucket \
      --bucket "${BUCKET}" \
      --region "${REGION}" \
      --create-bucket-configuration LocationConstraint="${REGION}"
  fi
  echo "    Bucket created."
fi

echo "==> Enabling versioning on ${BUCKET}"
aws s3api put-bucket-versioning \
  --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

echo "==> Enabling KMS server-side encryption on ${BUCKET}"
aws s3api put-bucket-encryption \
  --bucket "${BUCKET}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "aws:kms"
      },
      "BucketKeyEnabled": true
    }]
  }'

echo "==> Blocking all public access on ${BUCKET}"
aws s3api put-public-access-block \
  --bucket "${BUCKET}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "==> Applying HTTPS-only bucket policy on ${BUCKET}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3api put-bucket-policy \
  --bucket "${BUCKET}" \
  --policy "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Sid\": \"DenyNonTLSRequests\",
        \"Effect\": \"Deny\",
        \"Principal\": \"*\",
        \"Action\": \"s3:*\",
        \"Resource\": [
          \"arn:aws:s3:::${BUCKET}\",
          \"arn:aws:s3:::${BUCKET}/*\"
        ],
        \"Condition\": {
          \"Bool\": {
            \"aws:SecureTransport\": \"false\"
          }
        }
      }
    ]
  }"

echo "==> Applying lifecycle rule to expire noncurrent state versions after 90 days"
aws s3api put-bucket-lifecycle-configuration \
  --bucket "${BUCKET}" \
  --lifecycle-configuration '{
    "Rules": [{
      "ID": "expire-old-state-versions",
      "Status": "Enabled",
      "Filter": { "Prefix": "" },
      "NoncurrentVersionExpiration": { "NoncurrentDays": 90 },
      "AbortIncompleteMultipartUpload": { "DaysAfterInitiation": 7 }
    }]
  }'

echo "==> Creating DynamoDB lock table: ${DYNAMO_TABLE}"
if aws dynamodb describe-table --table-name "${DYNAMO_TABLE}" --region "${REGION}" 2>/dev/null; then
  echo "    Table already exists, skipping creation."
else
  aws dynamodb create-table \
    --table-name "${DYNAMO_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"

  echo "    Waiting for table to become ACTIVE..."
  aws dynamodb wait table-exists \
    --table-name "${DYNAMO_TABLE}" \
    --region "${REGION}"
  echo "    Table ready."
fi

echo ""
echo "Backend ready. Update backend.tf files in each environment directory:"
echo ""
echo "  terraform {"
echo "    backend \"s3\" {"
echo "      bucket         = \"${BUCKET}\""
echo "      dynamodb_table = \"${DYNAMO_TABLE}\""
echo "      region         = \"${REGION}\""
echo "      encrypt        = true"
echo "      key            = \"<env>/terraform.tfstate\""
echo "    }"
echo "  }"

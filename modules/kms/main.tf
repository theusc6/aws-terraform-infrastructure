# Retrieve the current caller's identity so we can grant them key admin rights
# without hardcoding an ARN. This works correctly for both IAM users and assumed roles.
data "aws_caller_identity" "current" {}

# Customer-managed KMS key with automatic annual rotation.
# Rotation generates a new backing key material but keeps the same Key ID and alias,
# so existing ciphertexts continue to decrypt without any application changes.
resource "aws_kms_key" "this" {
  description             = var.description
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true # Rotate the backing key material every 365 days
  multi_region            = var.multi_region

  # The key policy follows least-privilege: the root account retains full emergency
  # access, and the deploying identity is granted administrative rights. AWS services
  # that need to use the key (e.g. S3, EBS) are granted via IAM policies on their
  # principals — not here — which keeps the blast radius small.
  policy = var.key_policy != null ? var.key_policy : jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountFullAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowKeyAdministration"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_caller_identity.current.arn
        }
        Action = [
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
        ]
        Resource = "*"
      },
    ]
  })

  tags = merge(
    {
      Name        = var.alias_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Human-readable alias. KMS key IDs are UUID-style and impossible to identify
# at a glance. An alias like alias/prod-app makes audit logs readable.
resource "aws_kms_alias" "this" {
  name          = "alias/${var.alias_name}"
  target_key_id = aws_kms_key.this.key_id
}

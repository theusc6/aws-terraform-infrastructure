# Unit tests for modules/iam
# Run with: terraform -chdir=modules/iam test

mock_provider "aws" {}

# ── Test: role is created with the correct name ───────────────────────────────

run "role_name_is_set" {
  command = plan

  variables {
    role_name    = "test-ec2-role"
    trust_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
  }

  assert {
    condition     = aws_iam_role.this.name == "test-ec2-role"
    error_message = "IAM role name must match the role_name variable."
  }
}

# ── Test: ManagedBy tag is always applied ─────────────────────────────────────

run "managed_by_tag_always_present" {
  command = plan

  variables {
    role_name    = "test-ec2-role"
    trust_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
  }

  assert {
    condition     = aws_iam_role.this.tags["ManagedBy"] == "Terraform"
    error_message = "ManagedBy=Terraform tag must always be applied to the IAM role."
  }
}

# ── Test: instance profile is created when requested ─────────────────────────

run "instance_profile_created_when_requested" {
  command = plan

  variables {
    role_name               = "test-ec2-role"
    trust_policy            = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    create_instance_profile = true
  }

  assert {
    condition     = length(aws_iam_instance_profile.this) == 1
    error_message = "Instance profile must be created when create_instance_profile = true."
  }
}

# ── Test: instance profile is NOT created by default ─────────────────────────

run "instance_profile_not_created_by_default" {
  command = plan

  variables {
    role_name    = "test-ec2-role"
    trust_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
  }

  assert {
    condition     = length(aws_iam_instance_profile.this) == 0
    error_message = "Instance profile must not be created unless create_instance_profile = true."
  }
}

# ── Test: no policy attachments when policy_arns is empty ────────────────────

run "no_attachments_when_policy_arns_empty" {
  command = plan

  variables {
    role_name    = "test-ec2-role"
    trust_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    policy_arns  = []
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == 0
    error_message = "No policy attachments should be created when policy_arns is empty."
  }
}

# ── Test: correct number of policy attachments ────────────────────────────────

run "policy_attachments_created_for_each_arn" {
  command = plan

  variables {
    role_name    = "test-ec2-role"
    trust_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Principal\":{\"Service\":\"ec2.amazonaws.com\"},\"Action\":\"sts:AssumeRole\"}]}"
    policy_arns = [
      "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
      "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    ]
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.this) == 2
    error_message = "One policy attachment must be created per ARN in policy_arns."
  }
}

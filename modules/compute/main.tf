locals {
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.name}-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  user_data     = var.user_data

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = var.security_group_ids
    delete_on_termination       = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn  # Customer-managed key; null falls back to AWS-managed
      delete_on_termination = true
    }
  }

  dynamic "iam_instance_profile" {
    for_each = var.iam_instance_profile != null ? [1] : []
    content {
      name = var.iam_instance_profile
    }
  }

  # IMDSv2 — require signed token requests for the instance metadata service.
  # This prevents SSRF attacks from being able to reach the metadata API, which
  # would otherwise expose the instance's IAM credentials.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = var.name
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "${var.name}-volume"
    })
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "this" {
  name_prefix         = "${var.name}-"
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity

  # Use ELB health checks when an ALB target group is attached so that
  # instances failing ALB health checks are replaced — not just EC2 checks.
  health_check_type         = length(var.target_group_arns) > 0 ? "ELB" : "EC2"
  health_check_grace_period = var.health_check_grace_period

  # Pin to the specific version created by this apply rather than "$Latest".
  # Using $Latest means an unrelated launch template update could trigger an
  # unexpected rolling refresh outside of your planned deployment window.
  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  # Wire up ALB target groups so the ASG registers/deregisters instances automatically.
  target_group_arns = var.target_group_arns

  # Rolling refresh replaces instances with the new launch template version in
  # batches, ensuring at least min_healthy_percentage are healthy at all times.
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  dynamic "tag" {
    for_each = merge(local.common_tags, { Name = var.name })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    # External autoscaling policies (e.g. scheduled or target-tracking) may
    # adjust desired_capacity. Ignoring it here prevents Terraform from
    # fighting those adjustments on every plan.
    ignore_changes = [desired_capacity]
  }
}

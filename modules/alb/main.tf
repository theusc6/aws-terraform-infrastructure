locals {
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# ── Target Group ──────────────────────────────────────────────────────────────
# The target group is the destination for traffic routed by the ALB listener.
# We register EC2 instances via the ASG's target_group_arns — not here —
# so the membership is managed entirely by the Auto Scaling Group.

resource "aws_lb_target_group" "this" {
  name        = "${var.name}-tg"
  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  # Deregistration delay: time (seconds) the ALB waits for in-flight requests
  # to complete before removing a deregistering instance from service.
  deregistration_delay = var.deregistration_delay

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = merge(local.common_tags, {
    Name = "${var.name}-tg"
  })

  # Replace the old target group before destroying the new one when settings
  # change — prevents the 400ms window during which no healthy targets exist.
  lifecycle {
    create_before_destroy = true
  }
}

# ── Application Load Balancer ─────────────────────────────────────────────────

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids

  # Prevent accidental deletion of a load balancer that is serving live traffic.
  enable_deletion_protection = var.enable_deletion_protection

  idle_timeout = var.idle_timeout

  # Forward the originating client IP to backend instances via the
  # X-Forwarded-For header, which is added by ALBs automatically.

  tags = merge(local.common_tags, {
    Name = "${var.name}-alb"
  })
}

# ── HTTP Listener ─────────────────────────────────────────────────────────────
# When a certificate ARN is provided, redirect all HTTP traffic to HTTPS.
# When no certificate is configured (e.g. dev), forward directly to the target group.

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = var.certificate_arn != null ? ["redirect"] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.certificate_arn == null ? ["forward"] : []
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.this.arn
    }
  }
}

# ── HTTPS Listener ────────────────────────────────────────────────────────────
# Created only when an ACM certificate ARN is provided.
# In production, provision a certificate via aws_acm_certificate (or import an
# existing one) and pass its ARN via var.certificate_arn.

resource "aws_lb_listener" "https" {
  count = var.certificate_arn != null ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

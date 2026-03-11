variable "name" {
  description = "Name prefix for all ALB resources (ALB, target group, listeners)."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID in which the ALB and target group will be created."
  type        = string
}

variable "subnet_ids" {
  description = "List of public subnet IDs across multiple AZs. The ALB requires at least two subnets in different AZs."
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the ALB. The SG should allow inbound 80/443 from the internet."
  type        = list(string)
}

variable "internal" {
  description = "Set to true for an internal (private) ALB. False creates an internet-facing ALB."
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Prevent accidental deletion of the ALB via the AWS Console or API. Always enable this in production."
  type        = bool
  default     = false
}

variable "idle_timeout" {
  description = "Time in seconds the ALB waits for a client to send a request before closing the connection."
  type        = number
  default     = 60
}

variable "target_port" {
  description = "Port on which targets (EC2 instances) receive traffic from the ALB."
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "HTTP path the ALB uses to assess target health. The path must return a 2xx or 3xx status."
  type        = string
  default     = "/health"
}

variable "deregistration_delay" {
  description = "Seconds the ALB waits after a target begins deregistering before completing deregistration. Allows in-flight requests to complete."
  type        = number
  default     = 30
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. When provided, the HTTP listener redirects to HTTPS (301) and an HTTPS listener is created. Leave null to serve HTTP only (suitable for dev/staging without a domain)."
  type        = string
  default     = null
}

variable "ssl_policy" {
  description = "SSL/TLS negotiation policy for the HTTPS listener. ELBSecurityPolicy-TLS13-1-2-2021-06 is the recommended modern policy."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "tags" {
  description = "Additional tags to apply to all ALB resources."
  type        = map(string)
  default     = {}
}

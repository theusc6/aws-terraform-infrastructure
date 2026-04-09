variable "domain_name" {
  description = "Primary domain name for the ACM certificate (e.g. app.example.com or example.com)."
  type        = string
}

variable "subject_alternative_names" {
  description = "Additional domain names covered by this certificate (SANs). Common pattern: if the primary domain is app.example.com, add example.com here so a single cert covers both."
  type        = list(string)
  default     = []
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID in which to create the DNS validation CNAME records. The zone must be authoritative for var.domain_name."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod). Used as a tag."
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to the ACM certificate."
  type        = map(string)
  default     = {}
}

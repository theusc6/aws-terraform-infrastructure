variable "domain_name" {
  description = "The root domain name for the Route 53 hosted zone (e.g. example.com). This is the zone apex — do not include a subdomain here."
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, staging, prod). Used in the hosted zone comment and as a tag."
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to the hosted zone."
  type        = map(string)
  default     = {}
}

terraform {
  required_providers {
    aws = {
      region = var.region
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

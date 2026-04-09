module "vpc_endpoint_s3" {
  source        = "github.com/theusc6/terraform-infrastructure//modules/networking/vpc-endpoint-module?ref=v0.1.0"
  vpc_id        = "vpc-12345678"
  service_name  = "com.amazonaws.region.s3"
  endpoint_type = "Gateway"
}

output "endpoint_id" {
  value = module.vpc_endpoint_s3.vpc_endpoint_id
}

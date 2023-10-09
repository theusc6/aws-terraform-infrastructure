module "vpc_endpoint_s3" {
  source        = "path-to-your-module/vpc-endpoint-module"
  vpc_id        = "vpc-12345678"
  service_name  = "com.amazonaws.region.s3"
  endpoint_type = "Gateway"
}

output "endpoint_id" {
  value = module.vpc_endpoint_s3.vpc_endpoint_id
}
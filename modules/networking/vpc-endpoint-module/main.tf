resource "aws_vpc_endpoint" "this" {
  vpc_id            = var.vpc_id
  service_name      = var.service_name
  vpc_endpoint_type = var.endpoint_type

  security_group_ids = var.security_group_ids
  subnet_ids         = var.endpoint_type == "Interface" ? var.subnet_ids : []

  tags = {
    Name = "VPC Endpoint for ${var.service_name}"
  }
}

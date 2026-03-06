resource "aws_vpc_endpoint" "this" {
  vpc_id            = var.vpc_id
  service_name      = var.service_name
  vpc_endpoint_type = var.endpoint_type

  # security_group_ids and subnet_ids are only valid for Interface endpoints.
  # Gateway endpoints (e.g. S3, DynamoDB) use route table associations instead.
  security_group_ids = var.endpoint_type == "Interface" ? var.security_group_ids : []
  subnet_ids         = var.endpoint_type == "Interface" ? var.subnet_ids : []

  # For Gateway endpoints, associate with the supplied route tables.
  route_table_ids = var.endpoint_type == "Gateway" ? var.route_table_ids : []

  tags = merge(
    {
      Name      = "vpc-endpoint-${var.service_name}"
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

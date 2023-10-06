output "vpc_endpoint_id" {
  description = "The ID of the VPC endpoint."
  value       = aws_vpc_endpoint.this.id
}

output "vpc_endpoint_dns_entry" {
  description = "The DNS entries for the VPC endpoint."
  value       = aws_vpc_endpoint.this.dns_entry
}

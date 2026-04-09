output "zone_id" {
  description = "The hosted zone ID. Pass this to the ACM module's hosted_zone_id variable so certificate validation records are created in the correct zone. Also use it when creating the ALB alias record in the environment root module."
  value       = aws_route53_zone.this.zone_id
}

output "name_servers" {
  description = "The four Route 53 name servers delegated to this hosted zone. Update your domain registrar's NS records to these values to activate DNS resolution through this zone."
  value       = aws_route53_zone.this.name_servers
}

output "zone_name" {
  description = "The domain name of the hosted zone."
  value       = aws_route53_zone.this.name
}

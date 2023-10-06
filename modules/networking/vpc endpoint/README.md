# VPC Endpoint Module

This module provisions a VPC endpoint in AWS.

## Usage
To implement the VPC endpoint module, use the following code:

```
module "vpc_endpoint_s3" {
  source        = "./vpc-endpoint-module"
  vpc_id        = "vpc-12345678"
  service_name  = "com.amazonaws.region.s3"
  endpoint_type = "Gateway"
}

output "endpoint_id" {
  value = module.vpc_endpoint_s3.vpc_endpoint_id
}
```

## Inputs
| Name                | Description                                         | Type           | Default  | Required |
|---------------------|-----------------------------------------------------|----------------|----------|----------|
| `vpc_id`            | ID of the VPC in which the endpoint will be created. | `string`       | N/A      | Yes      |
| `service_name`      | Service name for the VPC endpoint.                  | `string`       | N/A      | Yes      |
| `endpoint_type`     | Type of the VPC endpoint (`Gateway` or `Interface`).| `string`       | `Interface` | No   |
| `security_group_ids`| Security group IDs associated with the endpoint.    | `list(string)` | `[]`     | No       |
| `subnet_ids`        | Subnet IDs for the endpoint (for Interface type).   | `list(string)` | `[]`     | No       |


## Outputs
| Name                     | Description                                |
|--------------------------|--------------------------------------------|
| `vpc_endpoint_id`        | ID of the VPC endpoint.                    |
| `vpc_endpoint_dns_entry` | DNS entries associated with the VPC endpoint. |


## Requirements
Relevant Terraform version & AWS Provider version
 

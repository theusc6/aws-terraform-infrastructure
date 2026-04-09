# modules/networking/vpc-module

Creates a **Virtual Private Cloud** with public and private subnets across multiple availability zones, Internet Gateway, NAT Gateways, route tables, and optional VPC Flow Logs.

Key design decisions:
- **Public subnets** map public IPs on launch and route to the Internet Gateway — intended for load balancers and NAT Gateways only.
- **Private subnets** have no public IP assignment and route to NAT Gateways — intended for application EC2 instances and data stores.
- **NAT Gateway mode** is configurable: a single shared NAT Gateway reduces cost but is a single point of failure; one NAT Gateway per AZ provides full high availability.
- **VPC Flow Logs** capture all `ACCEPT` and `REJECT` traffic metadata to CloudWatch Logs. Enabled by default. This is a CIS AWS Foundations Benchmark requirement.

---

## Usage

### Development (single NAT Gateway, 2 AZs)

```hcl
module "vpc" {
  source = "../../modules/networking/vpc-module"

  environment = "dev"
  vpc_cidr    = "10.0.0.0/16"
  azs         = ["us-west-2a", "us-west-2b"]

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true   # cost-optimised; not HA
}
```

### Production (one NAT Gateway per AZ, 3 AZs)

```hcl
module "vpc" {
  source = "../../modules/networking/vpc-module"

  environment = "prod"
  vpc_cidr    = "10.2.0.0/16"
  azs         = ["us-west-2a", "us-west-2b", "us-west-2c"]

  public_subnet_cidrs = [
    "10.2.1.0/24",
    "10.2.2.0/24",
    "10.2.3.0/24",
  ]
  private_subnet_cidrs = [
    "10.2.11.0/24",
    "10.2.12.0/24",
    "10.2.13.0/24",
  ]

  enable_nat_gateway       = true
  single_nat_gateway       = false   # one NAT GW per AZ for full HA
  enable_flow_logs         = true
  flow_logs_retention_days = 90
}
```

### Passing subnet IDs to other modules

```hcl
module "alb" {
  source     = "../../modules/alb"
  subnet_ids = module.vpc.public_subnet_ids    # ALB lives in public subnets
  vpc_id     = module.vpc.vpc_id
  # ...
}

module "compute" {
  source     = "../../modules/compute"
  subnet_ids = module.vpc.private_subnet_ids   # EC2 lives in private subnets
  # ...
}
```

---

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.3.0 |
| aws | ~> 5.0 |

---

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `environment` | Environment name (e.g. dev, staging, prod). Used in resource names and tags. | `string` | — | yes |
| `azs` | List of availability zone names. Must have at least two for HA. The number of AZs determines subnet count. | `list(string)` | — | yes |
| `vpc_cidr` | CIDR block for the VPC. | `string` | `"10.0.0.0/16"` | no |
| `public_subnet_cidrs` | CIDR blocks for public subnets. One per AZ. Must be within `vpc_cidr`. | `list(string)` | `[]` | no |
| `private_subnet_cidrs` | CIDR blocks for private subnets. One per AZ. Must be within `vpc_cidr`. | `list(string)` | `[]` | no |
| `enable_nat_gateway` | Create NAT Gateway(s) for private subnet egress. Set to `false` to remove internet access from private subnets (e.g. fully air-gapped environments using VPC endpoints). | `bool` | `true` | no |
| `single_nat_gateway` | Use a single NAT Gateway shared across all private subnets instead of one per AZ. Reduces cost but removes AZ-level HA for egress traffic. | `bool` | `false` | no |
| `enable_dns_hostnames` | Enable DNS hostnames in the VPC. Required for some services (e.g. ECS, EFS). | `bool` | `true` | no |
| `enable_dns_support` | Enable DNS resolution in the VPC. | `bool` | `true` | no |
| `enable_flow_logs` | Capture VPC traffic metadata in CloudWatch Logs. Recommended for all environments. | `bool` | `true` | no |
| `flow_logs_retention_days` | Number of days to retain VPC Flow Log entries in CloudWatch Logs. | `number` | `30` | no |
| `tags` | Additional tags applied to all resources. | `map(string)` | `{}` | no |

---

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | The ID of the VPC. |
| `vpc_cidr` | The CIDR block of the VPC. |
| `public_subnet_ids` | List of public subnet IDs (one per AZ). Pass to the ALB module. |
| `private_subnet_ids` | List of private subnet IDs (one per AZ). Pass to the compute module. |
| `nat_gateway_ids` | List of NAT Gateway IDs. |
| `internet_gateway_id` | The ID of the Internet Gateway. |
| `public_route_table_id` | The ID of the shared public route table. |
| `private_route_table_ids` | List of private route table IDs (one per AZ when NAT is enabled). |
| `flow_log_group_name` | CloudWatch Log Group name for VPC Flow Logs. Empty string when flow logs are disabled. |

---

## Notes

### Subnet sizing

Each subnet's CIDR should be sized to accommodate your maximum number of resources per AZ, plus AWS's 5-address reservation per subnet. A `/24` gives 251 usable addresses, which is sufficient for most workloads. Use `/22` (1019 addresses) for large deployments.

### NAT Gateway cost

NAT Gateway charges include:
- An hourly rate per NAT Gateway (~$0.045/hour in us-east-1)
- A per-GB data processing charge (~$0.045/GB in us-east-1)

For development environments with `single_nat_gateway = true`, one NAT Gateway is sufficient. For production with `single_nat_gateway = false` and 3 AZs, three NAT Gateways are created — this triples the hourly cost but eliminates cross-AZ failure dependency.

### VPC Flow Logs

Flow Logs record metadata (source IP, destination IP, port, protocol, bytes, action) for all traffic in and out of the VPC. They do **not** capture the packet payload. This data is useful for:
- Security incident investigation
- Network troubleshooting
- Compliance (CIS AWS Benchmark control 3.9)

The IAM role and policy for flow logs are created by this module — no external setup required.

### CIDR planning

Avoid overlapping CIDRs between environments if you plan to use VPC peering or AWS Transit Gateway in future. A common allocation strategy:

| Environment | VPC CIDR |
|-------------|----------|
| dev | `10.0.0.0/16` |
| staging | `10.1.0.0/16` |
| prod | `10.2.0.0/16` |

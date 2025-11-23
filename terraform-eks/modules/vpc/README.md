# VPC Module

Terraform module để tạo VPC với public/private subnets cho EKS cluster.

## Features

- VPC với custom CIDR
- 3 public subnets across 3 AZs
- 3 private subnets across 3 AZs
- Internet Gateway
- Configurable NAT Gateways (1-3)
- Proper tags for EKS

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  nat_gateway_count    = 3
  cluster_name         = "my-eks-cluster"
  
  common_tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| vpc_cidr | VPC CIDR block | string | required |
| public_subnet_cidrs | Public subnet CIDRs | list(string) | required |
| private_subnet_cidrs | Private subnet CIDRs | list(string) | required |
| nat_gateway_count | Number of NAT Gateways | number | 1 |
| cluster_name | EKS cluster name | string | required |
| common_tags | Common tags | map(string) | {} |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| vpc_cidr | VPC CIDR block |
| public_subnet_ids | Public subnet IDs |
| private_subnet_ids | Private subnet IDs |
| nat_gateway_ids | NAT Gateway IDs |
| internet_gateway_id | Internet Gateway ID |

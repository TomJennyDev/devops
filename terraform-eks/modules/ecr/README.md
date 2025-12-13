# ECR Module

Terraform module để tạo và quản lý AWS Elastic Container Registry (ECR) repositories với security best practices.

## Features

- ✅ **Security**: Encryption at rest (AES256 hoặc KMS), image scanning on push
- ✅ **Lifecycle Policies**: Auto-delete old images, cleanup untagged images
- ✅ **Tag Immutability**: Optional tag immutability cho production
- ✅ **Pull Through Cache**: Cache images từ public registries (Docker Hub, Quay, etc.)
- ✅ **Repository Policies**: Custom IAM policies cho cross-account access

## Usage

### Basic Example

```hcl
module "ecr" {
  source = "./modules/ecr"

  repositories = {
    "flowise-server" = {
      scan_on_push = true
      max_image_count = 30
    }
    "flowise-ui" = {
      scan_on_push = true
      max_image_count = 30
    }
  }

  common_tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
```

### Advanced Example

```hcl
module "ecr" {
  source = "./modules/ecr"

  repositories = {
    "app-backend" = {
      image_tag_mutability = "IMMUTABLE"  # Production: prevent tag overwrites
      scan_on_push         = true
      max_image_count      = 50
      untagged_days        = 3
      tags = {
        Component = "backend"
      }
    }
    "app-frontend" = {
      image_tag_mutability = "MUTABLE"    # Dev: allow tag updates
      scan_on_push         = true
      max_image_count      = 20
      untagged_days        = 7
      tags = {
        Component = "frontend"
      }
    }
  }

  # Use KMS encryption
  encryption_type = "KMS"
  kms_key_arn     = "arn:aws:kms:ap-southeast-1:123456789012:key/xxxxx"

  # Pull through cache for Docker Hub
  pull_through_cache_rules = {
    "docker-hub" = {
      upstream_registry_url = "registry-1.docker.io"
    }
  }

  common_tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| repositories | Map of ECR repositories to create | `map(object)` | `{}` | yes |
| encryption_type | Encryption type (AES256 or KMS) | `string` | `"AES256"` | no |
| kms_key_arn | KMS key ARN for encryption | `string` | `null` | no |
| force_delete | Delete repository even if contains images | `bool` | `false` | no |
| common_tags | Common tags for all resources | `map(string)` | `{}` | no |
| pull_through_cache_rules | Pull through cache rules | `map(object)` | `{}` | no |

### Repository Object

```hcl
{
  image_tag_mutability = "MUTABLE"    # MUTABLE or IMMUTABLE
  scan_on_push         = true         # Enable vulnerability scanning
  max_image_count      = 30           # Keep last N images
  untagged_days        = 7            # Delete untagged after N days
  repository_policy    = null         # JSON IAM policy
  tags                 = {}           # Additional tags
}
```

## Outputs

| Name | Description |
|------|-------------|
| repository_urls | Map of repository names to URLs |
| repository_arns | Map of repository names to ARNs |
| repository_registry_ids | Map of repository names to registry IDs |
| flowise_server_url | ECR URL for flowise-server |
| flowise_ui_url | ECR URL for flowise-ui |
| docker_login_command | Command to authenticate Docker with ECR |

## Lifecycle Policies

Module tự động tạo 2 lifecycle rules:

1. **Keep Last N Images**: Giữ lại N images mới nhất (default: 30)
2. **Expire Untagged Images**: Xóa untagged images sau N ngày (default: 7)

## Image Scanning

Khi `scan_on_push = true`:
- Mỗi image được push sẽ tự động scan vulnerabilities
- Xem scan results: `aws ecr describe-image-scan-findings --repository-name <repo> --image-id imageTag=<tag>`
- Integration với Security Hub để centralized monitoring

## Docker Login

Sau khi tạo ECR repositories:

```bash
# Get login command from output
terraform output docker_login_command

# Or manually
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-southeast-1.amazonaws.com
```

## Push Images

```bash
# Tag image
docker tag flowise-server:latest <account-id>.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-server:latest

# Push image
docker push <account-id>.dkr.ecr.ap-southeast-1.amazonaws.com/flowise-server:latest
```

## Cross-Account Access

Để cho phép account khác pull images:

```hcl
repositories = {
  "shared-app" = {
    repository_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "AllowCrossAccountPull"
          Effect = "Allow"
          Principal = {
            AWS = "arn:aws:iam::123456789012:root"
          }
          Action = [
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "ecr:BatchCheckLayerAvailability"
          ]
        }
      ]
    })
  }
}
```

## Pull Through Cache

Cache images từ public registries để:
- Giảm rate limits (Docker Hub: 100 pulls/6h → unlimited)
- Tăng tốc độ pull (cache ở region gần)
- Improve availability (không phụ thuộc external registry)

```hcl
pull_through_cache_rules = {
  "docker-hub" = {
    upstream_registry_url = "registry-1.docker.io"
  }
  "quay" = {
    upstream_registry_url = "quay.io"
  }
  "gcr" = {
    upstream_registry_url = "gcr.io"
  }
}
```

Usage:
```bash
# Instead of: docker pull nginx:latest
docker pull <account-id>.dkr.ecr.ap-southeast-1.amazonaws.com/docker-hub/nginx:latest
```

## Security Best Practices

### Development
- ✅ `image_tag_mutability = "MUTABLE"` - Allow tag updates
- ✅ `scan_on_push = true` - Always scan
- ✅ `max_image_count = 20` - Keep fewer images
- ✅ `untagged_days = 3` - Quick cleanup

### Production
- ✅ `image_tag_mutability = "IMMUTABLE"` - Prevent tag overwrites
- ✅ `scan_on_push = true` - Always scan
- ✅ `max_image_count = 100` - Keep more for rollback
- ✅ `untagged_days = 1` - Immediate cleanup
- ✅ Use KMS encryption for sensitive data
- ✅ Enable repository policies for least-privilege access

## Cost Optimization

- **Storage**: $0.10/GB/month (first 500 MB free)
- **Data Transfer**: Out to internet has charges, within AWS free
- **Lifecycle Policies**: Auto-delete old images to reduce storage costs
- **Pull Through Cache**: Reduce external data transfer costs

Example costs:
- 10 repos × 10 images × 500 MB = 50 GB = **$5/month**
- With lifecycle (keep last 3): 10 repos × 3 images × 500 MB = 15 GB = **$1.50/month**

## Monitoring

```bash
# List repositories
aws ecr describe-repositories

# List images in repository
aws ecr list-images --repository-name flowise-server

# Get image scan results
aws ecr describe-image-scan-findings \
  --repository-name flowise-server \
  --image-id imageTag=latest

# Check lifecycle policy
aws ecr get-lifecycle-policy --repository-name flowise-server
```

## Troubleshooting

### Error: "no basic auth credentials"
```bash
# Re-authenticate (credentials expire after 12 hours)
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-southeast-1.amazonaws.com
```

### Error: "image with tag already exists"
- If `image_tag_mutability = "IMMUTABLE"`: Use different tag
- If `image_tag_mutability = "MUTABLE"`: Push will overwrite

### Scan findings not showing
- Wait up to 15 minutes after push
- Check scan status: `aws ecr describe-images --repository-name <repo>`

## Examples

See `terraform-eks/environments/dev/terraform.tfvars` for complete example configuration.

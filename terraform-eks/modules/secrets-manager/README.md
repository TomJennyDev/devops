# AWS Secrets Manager Module

## Overview
Manages sensitive credentials and secrets using AWS Secrets Manager with encryption at rest and IAM-based access control.

## Features
- ✅ Encrypted secret storage (KMS)
- ✅ Secret versioning
- ✅ Automated IAM policy generation
- ✅ Configurable recovery window
- ✅ Multiple secret types support

## Usage

```hcl
module "secrets" {
  source = "../../modules/secrets-manager"

  cluster_name = "my-eks"
  environment  = "dev"

  secrets = {
    grafana-admin = {
      description = "Grafana admin credentials"
      type        = "password"
      value = {
        username = "admin"
        password = "SecurePassword123!"
      }
    }
    
    flowise-db = {
      description = "Flowise database credentials"
      type        = "database"
      value = {
        host     = "db.example.com"
        port     = "5432"
        username = "flowise"
        password = "SecureDBPass456!"
        database = "flowise"
      }
    }
  }

  recovery_window_days  = 7
  create_access_policy  = true

  common_tags = {
    Project   = "EKS"
    ManagedBy = "Terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the EKS cluster | `string` | - | yes |
| environment | Environment name (dev, staging, prod) | `string` | - | yes |
| secrets | Map of secrets to create | `map(object)` | `{}` | no |
| recovery_window_days | Days before permanent deletion | `number` | `7` | no |
| create_access_policy | Create IAM policy for access | `bool` | `true` | no |
| common_tags | Common tags for all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| secret_arns | ARNs of created secrets |
| secret_ids | IDs of created secrets |
| secret_names | Names of created secrets |
| access_policy_arn | ARN of IAM policy for secret access |

## Security Best Practices

1. **Never commit secrets to version control**
   - Use `.gitignore` for sensitive files
   - Store secrets in CI/CD secret management

2. **Use least privilege IAM policies**
   - Only grant access to required secrets
   - Use resource-based policies when possible

3. **Enable secret rotation**
   - Implement automated rotation for database credentials
   - Use AWS Lambda for custom rotation logic

4. **Monitor secret access**
   - Enable CloudTrail logging
   - Set up CloudWatch alarms for unauthorized access

## Retrieving Secrets

### In Terraform (other modules)
```hcl
data "aws_secretsmanager_secret_version" "grafana" {
  secret_id = "my-eks-dev-grafana-admin"
}

locals {
  grafana_creds = jsondecode(data.aws_secretsmanager_secret_version.grafana.secret_string)
}
```

### In Kubernetes (External Secrets Operator)
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets
spec:
  provider:
    aws:
      service: SecretsManager
      region: ap-southeast-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: grafana-admin
spec:
  secretStoreRef:
    name: aws-secrets
  target:
    name: grafana-admin-secret
  data:
    - secretKey: username
      remoteRef:
        key: my-eks-dev-grafana-admin
        property: username
    - secretKey: password
      remoteRef:
        key: my-eks-dev-grafana-admin
        property: password
```

## Cost Considerations
- $0.40 per secret per month
- $0.05 per 10,000 API calls
- Free tier: 30 days for first secret

## Limitations
- Secret size: max 65,536 bytes
- Secret name: 512 characters max
- 500 versions per secret

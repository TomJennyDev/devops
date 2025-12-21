# GitHub Actions Workflow Setup Guide

## ⚠️ Current Issues

Your `terraform.yml` workflow has validation errors that need to be fixed:

### 1. Missing GitHub Secrets

The workflow references these secrets that haven't been created yet:

```
❌ AWS_ROLE_ARN_DEV        (used in plan-dev, apply-dev jobs)
❌ AWS_ROLE_ARN_STAGING    (used in plan-staging, apply-staging jobs)  
❌ AWS_ROLE_ARN_PROD       (used in plan-prod, apply-prod jobs)
```

### 2. Missing GitHub Environments

The workflow requires these environments to be created in GitHub repository settings:

```
❌ dev
❌ staging
❌ prod
```

---

## 🔧 Setup Instructions

### Step 1: Create AWS IAM Roles for OIDC

You need to create IAM roles with OIDC trust policy for GitHub Actions:

```bash
# For each environment (dev, staging, prod), create an IAM role with:

# Trust Policy:
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::{AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:TomJennyDev/devops:*"
        }
      }
    }
  ]
}

# Attach necessary policies:
# - AdministratorAccess (for full Terraform access)
# OR create custom policy with minimum required permissions
```

**Role Names Example:**

- `github-actions-terraform-dev-role`
- `github-actions-terraform-staging-role`
- `github-actions-terraform-prod-role`

**Note:** First, you need to create the OIDC provider in AWS IAM:

1. Go to IAM Console → Identity Providers → Add Provider
2. Provider Type: OpenID Connect
3. Provider URL: `https://token.actions.githubusercontent.com`
4. Audience: `sts.amazonaws.com`

### Step 2: Add GitHub Secrets

Go to your repository: **Settings → Secrets and variables → Actions → New repository secret**

Add these secrets:

```bash
# Dev Environment
Name: AWS_ROLE_ARN_DEV
Value: arn:aws:iam::{ACCOUNT_ID}:role/github-actions-terraform-dev-role

# Staging Environment  
Name: AWS_ROLE_ARN_STAGING
Value: arn:aws:iam::{ACCOUNT_ID}:role/github-actions-terraform-staging-role

# Production Environment
Name: AWS_ROLE_ARN_PROD
Value: arn:aws:iam::{ACCOUNT_ID}:role/github-actions-terraform-prod-role
```

### Step 3: Create GitHub Environments

Go to your repository: **Settings → Environments → New environment**

Create 3 environments:

#### Environment: `dev`

- ✅ No protection rules (auto-deploy on push to main)
- Environment secrets: (none needed - uses repository secrets)
- Deployment branches: `main` only

#### Environment: `staging`

- ✅ Required reviewers: (optional - add 1 reviewer)
- Wait timer: 0 minutes (or add delay if needed)
- Deployment branches: `main` only

#### Environment: `prod`

- ✅ **Required reviewers**: Add 1-2 reviewers (CRITICAL!)
- Wait timer: 5 minutes (recommended)
- Deployment branches: `main` only
- Environment URL: `https://yourdomain.com`

---

## 🚀 Workflow Execution Flow

```
Push to main (terraform-eks/** changes)
│
├─► validate (all environments) ✓
├─► security (tfsec, checkov) ✓
│
├─► plan-dev ✓
├─► apply-dev ✓ (auto-deploy)
│
├─► plan-staging ✓
├─► apply-staging ⏸️ (wait for approval if reviewer set)
│
└─► plan-prod ⏸️ (manual trigger via workflow_dispatch)
    └─► apply-prod ⏸️ (requires approval)
```

---

## 📋 Verification Checklist

Before the workflow can run successfully:

- [ ] AWS OIDC Provider created in IAM
- [ ] 3 IAM Roles created (dev, staging, prod) with trust policy
- [ ] 3 GitHub Secrets added (AWS_ROLE_ARN_DEV, AWS_ROLE_ARN_STAGING, AWS_ROLE_ARN_PROD)
- [ ] 3 GitHub Environments created (dev, staging, prod)
- [ ] Production environment has required reviewers configured
- [ ] Terraform backend S3 buckets exist for each environment
- [ ] DynamoDB tables for state locking exist

---

## 🔍 Testing the Workflow

1. **Test Validation Only** (on PR):

   ```bash
   git checkout -b test-workflow
   # Make a small change to terraform-eks/
   git commit -m "test: workflow validation"
   git push origin test-workflow
   # Create PR on GitHub → Workflow runs validation only
   ```

2. **Test Dev Deployment** (on main):

   ```bash
   git checkout main
   # Make a change to terraform-eks/
   git commit -m "feat: update dev config"
   git push origin main
   # Workflow auto-deploys to dev
   ```

3. **Test Prod Deployment** (manual):
   - Go to GitHub → Actions → Terraform CI/CD → Run workflow
   - Select: `main` branch, Environment: `prod`
   - Requires manual approval before apply

---

## 🐛 Troubleshooting

### Error: "Context access might be invalid: AWS_ROLE_ARN_DEV"

**Cause:** Secret not created in GitHub repository settings

**Fix:** Add the secret (see Step 2 above)

### Error: "Value 'dev' is not valid"

**Cause:** Environment not created in GitHub repository settings

**Fix:** Create the environment (see Step 3 above)

### Error: "AssumeRoleWithWebIdentity failed"

**Cause:** IAM role trust policy is incorrect or OIDC provider not configured

**Fix:**

1. Verify OIDC provider exists in AWS IAM
2. Check trust policy allows `repo:TomJennyDev/devops:*`
3. Verify role ARN in GitHub secret is correct

### Error: "Backend initialization failed"

**Cause:** S3 backend bucket or DynamoDB table doesn't exist

**Fix:** Check each environment's `backend.tf`:

```bash
# Dev
terraform-eks/environments/dev/backend.tf

# Staging  
terraform-eks/environments/staging/backend.tf

# Prod
terraform-eks/environments/prod/backend.tf
```

Ensure S3 buckets and DynamoDB tables are created first.

---

## 📚 References

- [GitHub Actions OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [Terraform GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- [AWS IAM OIDC Provider](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)

---

## 🎯 Quick Setup Commands

```bash
# Install GitHub CLI (if needed)
# Windows: winget install GitHub.cli
# macOS: brew install gh
# Linux: https://github.com/cli/cli#installation

# Login to GitHub
gh auth login

# Create secrets (after creating IAM roles)
gh secret set AWS_ROLE_ARN_DEV --body "arn:aws:iam::ACCOUNT_ID:role/github-actions-terraform-dev-role"
gh secret set AWS_ROLE_ARN_STAGING --body "arn:aws:iam::ACCOUNT_ID:role/github-actions-terraform-staging-role"  
gh secret set AWS_ROLE_ARN_PROD --body "arn:aws:iam::ACCOUNT_ID:role/github-actions-terraform-prod-role"

# Verify secrets
gh secret list
```

**Note:** Environments cannot be created via CLI - must be created in GitHub web UI.

---

## ✅ Once Setup is Complete

The workflow will automatically:

- ✅ Validate Terraform code on every PR
- ✅ Run security scans (tfsec, checkov)
- ✅ Plan changes for all environments
- ✅ Auto-deploy to dev on merge to main
- ⏸️ Wait for approval before staging deploy
- ⏸️ Require manual trigger + approval for production

---

**Last Updated:** 2025-12-21
**Workflow Version:** 1.0.0

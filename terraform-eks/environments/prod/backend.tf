# ========================================
# BACKEND CONFIGURATION - PRODUCTION
# ========================================
# S3 backend for remote state storage
# DynamoDB for state locking
# CRITICAL: Production state should have strict access control

terraform {
  backend "s3" {
    bucket         = "my-terraform-state-prod"
    key            = "eks/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-state-lock-prod"
    encrypt        = true
    
    # Additional production safeguards:
    # 1. Enable S3 bucket versioning
    # 2. Enable MFA delete on bucket
    # 3. Restrict IAM access to state bucket
    # 4. Enable CloudTrail logging for state access
  }
}

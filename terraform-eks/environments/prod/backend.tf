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
    
    # Optional: Use KMS for additional encryption control
    # kms_key_id = "arn:aws:kms:ap-southeast-1:372836560690:key/..." # Uncomment and add KMS key ARN if needed
    
    # Additional production safeguards:
    # 1. Enable S3 bucket versioning
    # 2. Enable MFA delete on bucket
    # 3. Restrict IAM access to state bucket
    # 4. Enable CloudTrail logging for state access
  }
}

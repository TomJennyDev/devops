# ========================================
# BACKEND CONFIGURATION - DEV
# ========================================
# S3 backend for remote state storage
# DynamoDB for state locking

terraform {
  backend "s3" {
    # S3 bucket for state file
    # MUST be created manually before running terraform init:
    # aws s3api create-bucket \
    #   --bucket terraform-state-372836560690-dev \
    #   --region ap-southeast-1 \
    #   --create-bucket-configuration LocationConstraint=ap-southeast-1
    
    bucket = "terraform-state-372836560690-dev"
    key    = "eks/terraform.tfstate"
    region = "ap-southeast-1"
    
    # DynamoDB table for state locking
    # MUST be created manually:
    # aws dynamodb create-table \
    #   --table-name terraform-state-lock-dev \
    #   --attribute-definitions AttributeName=LockID,AttributeType=S \
    #   --key-schema AttributeName=LockID,KeyType=HASH \
    #   --billing-mode PAY_PER_REQUEST \
    #   --region ap-southeast-1
    
    use_lockfile   = true
    dynamodb_table = "terraform-state-lock-dev"
    
    # Enable encryption at rest (AES-256)
    encrypt = true
    
    # Optional: Use KMS for additional encryption control
    # kms_key_id = "arn:aws:kms:ap-southeast-1:372836560690:key/..." # Uncomment and add KMS key ARN if needed
    
    # Enable versioning for state file recovery
    # Set on S3 bucket:
    # aws s3api put-bucket-versioning \
    #   --bucket my-terraform-state-dev \
    #   --versioning-configuration Status=Enabled
  }
}

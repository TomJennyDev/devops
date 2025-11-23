# ========================================
# BACKEND CONFIGURATION - STAGING
# ========================================
# S3 backend for remote state storage
# DynamoDB for state locking

terraform {
  backend "s3" {
    bucket         = "my-terraform-state-staging"
    key            = "eks/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "terraform-state-lock-staging"
    encrypt        = true
  }
}

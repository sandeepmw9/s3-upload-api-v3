# Backend Configuration for Terraform State
# Uncomment and configure to use S3 for remote state storage

# terraform {
#   backend "s3" {
#     bucket         = "my-terraform-state-bucket"
#     key            = "s3-upload-api-public-modules/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#   }
# }

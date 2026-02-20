# Main Terraform Configuration using Public AWS Modules
# Uses terraform-aws-modules for Lambda and API Gateway

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Local variables for common configurations
locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
  
  lambda_environment_variables = {
    S3_BUCKET_NAME       = module.s3_bucket.bucket_name
    MAX_FILE_SIZE_MB     = var.max_file_size_mb
    PRESIGNED_URL_EXPIRY = var.presigned_url_expiry
  }
}

# S3 Bucket using public module
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"

  bucket = var.bucket_name
  
  # Versioning
  versioning = {
    enabled = var.enable_versioning
  }
  
  # Server-side encryption
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
  
  # Block public access
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  
  # CORS configuration for browser uploads
  cors_rule = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["PUT", "POST"]
      allowed_origins = var.allowed_origins
      expose_headers  = ["ETag"]

      max_age_seconds = 3000
    }
  ]
  
  tags = merge(local.common_tags, {
    Name = var.bucket_name
  })
}

# Lambda function using public module
module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = var.lambda_function_name
  description   = "Handles file uploads and generates presigned URLs"
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_runtime
  
  source_path = "${path.module}/lambda"
  
  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size
  
  environment_variables = local.lambda_environment_variables
  
  # Attach policies
  attach_policy_statements = true
  policy_statements = {
    s3_write = {
      effect = "Allow"
      actions = [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject"
      ]
      resources = ["${module.s3_bucket.bucket_arn}/*"]
    }
  }
  
  # CloudWatch Logs
  attach_cloudwatch_logs_policy = true
  cloudwatch_logs_retention_in_days = var.log_retention_days
  
  # Allow API Gateway to invoke
  allowed_triggers = {
    APIGatewayAny = {
      service    = "apigateway"
      source_arn = "${module.api_gateway.api_execution_arn}/*/*"
    }
  }
  
  tags = merge(local.common_tags, {
    Name = var.lambda_function_name
  })
}

# API Gateway using public module (HTTP API - simpler and cheaper)
module "api_gateway" {
  source  = "terraform-aws-modules/apigateway-v2/aws"
  version = "~> 5.0"

  name          = var.api_name
  description   = "API Gateway for file uploads with presigned URL support"
  protocol_type = "HTTP"
  
  # CORS configuration
  cors_configuration = var.enable_cors ? {
    allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_origins = var.allowed_origins
  } : null
  
  # Routes
  routes = {
    "GET /upload" = {
      integration = {
        uri                    = module.lambda_function.lambda_function_arn
        payload_format_version = "2.0"
        timeout_milliseconds   = var.lambda_timeout * 1000
      }
    }
    
    "POST /upload" = {
      integration = {
        uri                    = module.lambda_function.lambda_function_arn
        payload_format_version = "2.0"
        timeout_milliseconds   = var.lambda_timeout * 1000
      }
    }
  }
  
  # Stage configuration
  stage_name = var.api_stage_name
  
  # Auto-deploy is handled by the module automatically when routes change
  create_stage = true
  
  # Throttling
  stage_default_route_settings = {
    throttling_burst_limit = var.throttle_burst_limit
    throttling_rate_limit  = var.throttle_rate_limit
  }
  
  tags = merge(local.common_tags, {
    Name = var.api_name
  })
}

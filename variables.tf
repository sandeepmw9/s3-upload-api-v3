# Root Variables for S3 Upload API using Public Modules

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "Must be a valid AWS region (e.g., us-east-1, eu-west-1)."
  }
}

variable "project_name" {
  description = "Name of the project, used for resource naming and tagging"
  type        = string
  default     = "s3-upload-api"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,32}$", var.project_name))
    error_message = "Project name must be 3-32 characters, lowercase letters, numbers, and hyphens only."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod, test)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod", "test"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod, test."
  }
}

# S3 Configuration
variable "bucket_name" {
  description = "Name of the S3 bucket for file storage (must be globally unique)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 characters, lowercase letters, numbers, and hyphens only."
  }

  validation {
    condition     = !can(regex("^xn--", var.bucket_name))
    error_message = "Bucket name cannot start with 'xn--'."
  }

  validation {
    condition     = !can(regex("\\.\\.|\\.\\-|\\-\\.", var.bucket_name))
    error_message = "Bucket name cannot contain consecutive periods or period-dash combinations."
  }
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

# Lambda Configuration
variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "upload-handler"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]{1,64}$", var.lambda_function_name))
    error_message = "Function name must be 1-64 characters, alphanumeric, hyphens, and underscores only."
  }
}

variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "python3.11"

  validation {
    condition     = contains(["python3.9", "python3.10", "python3.11", "python3.12"], var.lambda_runtime)
    error_message = "Runtime must be one of: python3.9, python3.10, python3.11, python3.12."
  }
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30

  validation {
    condition     = var.lambda_timeout >= 3 && var.lambda_timeout <= 900
    error_message = "Lambda timeout must be between 3 and 900 seconds."
  }
}

variable "lambda_memory_size" {
  description = "Lambda function memory in MB"
  type        = number
  default     = 256

  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "Memory size must be between 128 and 10240 MB."
  }

  validation {
    condition     = var.lambda_memory_size % 64 == 0
    error_message = "Memory size must be a multiple of 64 MB."
  }
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 7

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.log_retention_days)
    error_message = "Log retention must be a valid CloudWatch Logs retention period."
  }
}

# File Upload Configuration
variable "max_file_size_mb" {
  description = "Maximum file size in MB for direct uploads (via POST)"
  type        = number
  default     = 6

  validation {
    condition     = var.max_file_size_mb > 0 && var.max_file_size_mb <= 6
    error_message = "Max file size must be between 1 and 6 MB for direct uploads."
  }
}

variable "presigned_url_expiry" {
  description = "Presigned URL expiration time in seconds"
  type        = number
  default     = 3600

  validation {
    condition     = var.presigned_url_expiry >= 60 && var.presigned_url_expiry <= 604800
    error_message = "Presigned URL expiry must be between 60 seconds (1 min) and 604800 seconds (7 days)."
  }
}

# API Gateway Configuration
variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
  default     = "upload-api"

  validation {
    condition     = length(var.api_name) >= 1 && length(var.api_name) <= 128
    error_message = "API name must be between 1 and 128 characters."
  }
}

variable "api_stage_name" {
  description = "Name of the API Gateway deployment stage"
  type        = string
  default     = "prod"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_]{1,128}$", var.api_stage_name))
    error_message = "Stage name must be 1-128 characters, alphanumeric, hyphens, and underscores only."
  }
}

variable "enable_cors" {
  description = "Enable CORS for the API Gateway (required for browser uploads)"
  type        = bool
  default     = true
}

variable "allowed_origins" {
  description = "List of allowed origins for CORS (use ['*'] for all, or specific domains)"
  type        = list(string)
  default     = ["*"]

  validation {
    condition     = length(var.allowed_origins) > 0
    error_message = "At least one allowed origin must be specified."
  }

  validation {
    condition = alltrue([
      for origin in var.allowed_origins :
      origin == "*" || can(regex("^https?://", origin))
    ])
    error_message = "Origins must be '*' or start with http:// or https://."
  }
}

variable "throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 5000

  validation {
    condition     = var.throttle_burst_limit >= 0 && var.throttle_burst_limit <= 10000
    error_message = "Throttle burst limit must be between 0 and 10000."
  }
}

variable "throttle_rate_limit" {
  description = "API Gateway throttle rate limit (requests per second)"
  type        = number
  default     = 10000

  validation {
    condition     = var.throttle_rate_limit >= 0 && var.throttle_rate_limit <= 20000
    error_message = "Throttle rate limit must be between 0 and 20000."
  }
}

# Tags
variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k, v in var.tags : can(regex("^[\\w\\s+=.:\\/@-]{1,128}$", k))])
    error_message = "Tag keys must be 1-128 characters and contain only letters, numbers, spaces, and +=.:/@- characters."
  }

  validation {
    condition     = alltrue([for k, v in var.tags : length(v) <= 256])
    error_message = "Tag values must be 256 characters or less."
  }
}

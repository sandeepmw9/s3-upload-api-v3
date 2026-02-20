# Root Outputs for S3 Upload API using Public Modules

output "api_endpoint" {
  description = "Base URL of the API Gateway endpoint"
  value       = module.api_gateway.api_endpoint
}

output "api_endpoint_get_presigned_url" {
  description = "GET endpoint to generate presigned URL (for large files)"
  value       = "${module.api_gateway.api_endpoint}/upload?filename=example.pdf&contentType=application/pdf&maxSize=104857600"
}

output "api_endpoint_post_direct_upload" {
  description = "POST endpoint for direct upload (for small files < 6MB)"
  value       = "${module.api_gateway.api_endpoint}/upload"
}

output "api_id" {
  description = "ID of the API Gateway"
  value       = module.api_gateway.api_id
}

output "api_execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = module.api_gateway.api_execution_arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket storing uploaded files"
  value       = module.s3_bucket.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.s3_bucket.bucket_arn
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = module.s3_bucket.bucket_domain_name
}

output "lambda_function_name" {
  description = "Name of the Lambda function handling uploads"
  value       = module.lambda_function.lambda_function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.lambda_function.lambda_function_arn
}

output "lambda_function_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = module.lambda_function.lambda_function_invoke_arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = module.lambda_function.lambda_role_arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group for Lambda"
  value       = module.lambda_function.lambda_cloudwatch_log_group_name
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "usage_instructions" {
  description = "Instructions for using the API"
  value = <<-EOT
    
    ╔════════════════════════════════════════════════════════════════╗
    ║          S3 Upload API - Usage Instructions                    ║
    ╚════════════════════════════════════════════════════════════════╝
    
    📍 Region: ${var.aws_region}
    🪣 Bucket: ${module.s3_bucket.bucket_name}
    ⚡ Lambda: ${module.lambda_function.lambda_function_name}
    
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    🔹 For LARGE files (> 6MB, up to 5GB):
    
       1. Get presigned URL:
          GET ${module.api_gateway.api_endpoint}/upload?filename=large.pdf&contentType=application/pdf&maxSize=104857600
       
       2. Upload directly to S3 using returned presigned URL
    
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    🔹 For SMALL files (< 6MB):
    
       POST ${module.api_gateway.api_endpoint}/upload
       Content-Type: application/pdf
       Body: <base64-encoded file>
    
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    🔹 Browser upload:
    
       Open browser-upload-example.html
       Update API_ENDPOINT with: ${module.api_gateway.api_endpoint}/upload
    
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    📊 Monitoring:
    
       CloudWatch Logs: ${module.lambda_function.lambda_cloudwatch_log_group_name}
       
  EOT
}

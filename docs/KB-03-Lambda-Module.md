# Knowledge Base: Lambda Function Module

## Module Information

**Module Source**: `terraform-aws-modules/lambda/aws`
**Version**: ~> 7.0
**Registry**: https://registry.terraform.io/modules/terraform-aws-modules/lambda/aws

---

## Purpose

Creates a Lambda function that:
- Generates presigned URLs for large file uploads
- Handles direct uploads for small files
- Validates file format and size
- Manages S3 interactions

---

## Module Configuration

### Basic Configuration

```hcl
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
  
  environment_variables = {
    S3_BUCKET_NAME       = module.s3_bucket.bucket_name
    MAX_FILE_SIZE_MB     = var.max_file_size_mb
    PRESIGNED_URL_EXPIRY = var.presigned_url_expiry
  }
  
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
  
  attach_cloudwatch_logs_policy = true
  cloudwatch_logs_retention_in_days = 7
  
  allowed_triggers = {
    APIGatewayAny = {
      service    = "apigateway"
      source_arn = "${module.api_gateway.api_execution_arn}/*/*"
    }
  }
  
  tags = local.common_tags
}
```

---

## Arguments Explained

### Required Arguments

#### `function_name`
- **Type**: `string`
- **Description**: Name of the Lambda function
- **Constraints**: 1-64 characters, alphanumeric, hyphens, underscores
- **Example**: `"upload-handler"`
- **Best Practice**: Use descriptive names like `{project}-{purpose}`

#### `handler`
- **Type**: `string`
- **Description**: Entry point for Lambda execution
- **Format**: `{filename}.{function_name}`
- **Example**: `"lambda_function.lambda_handler"`
- **Note**: Must match Python file and function name

#### `runtime`
- **Type**: `string`
- **Description**: Lambda runtime environment
- **Options**: `python3.9`, `python3.10`, `python3.11`, `python3.12`
- **Recommendation**: `python3.11` (good balance of features and stability)
- **Deprecation**: Check AWS Lambda runtime support policy

#### `source_path`
- **Type**: `string`
- **Description**: Path to Lambda function code
- **Example**: `"${path.module}/lambda"`
- **Note**: Module automatically packages code into ZIP

### Performance Arguments

#### `timeout`
- **Type**: `number`
- **Description**: Maximum execution time in seconds
- **Range**: 3-900 seconds (15 minutes max)
- **Default**: 30 seconds
- **Recommendation**:
  - Presigned URL generation: 10-30 seconds
  - Direct upload (6MB): 30-60 seconds
- **Cost Impact**: Billed per 100ms of execution

#### `memory_size`
- **Type**: `number`
- **Description**: Memory allocated to function in MB
- **Range**: 128-10,240 MB
- **Increment**: Must be multiple of 64 MB
- **Default**: 256 MB
- **CPU Allocation**: Proportional to memory
  - 128 MB = 0.08 vCPU
  - 256 MB = 0.17 vCPU
  - 512 MB = 0.33 vCPU
  - 1024 MB = 0.67 vCPU
- **Cost Impact**: Higher memory = higher cost per invocation

**Memory Sizing Guide**:
```
File Size | Recommended Memory
----------|-------------------
< 1 MB    | 128 MB
1-5 MB    | 256 MB
5-10 MB   | 512 MB
> 10 MB   | Use presigned URL
```

### Environment Variables

#### `environment_variables`
- **Type**: `map(string)`
- **Description**: Configuration passed to Lambda function
- **Size Limit**: 4 KB total
- **Encryption**: Encrypted at rest

**Our Variables**:
```hcl
environment_variables = {
  S3_BUCKET_NAME       = "my-uploads-bucket"
  MAX_FILE_SIZE_MB     = "6"
  PRESIGNED_URL_EXPIRY = "3600"
}
```

**Access in Python**:
```python
import os
bucket = os.environ.get('S3_BUCKET_NAME')
```

### IAM Policy Configuration

#### `attach_policy_statements`
- **Type**: `bool`
- **Description**: Enable inline policy attachment
- **Default**: `false`
- **Set to**: `true` (to attach S3 permissions)

#### `policy_statements`
- **Type**: `map(object)`
- **Description**: IAM policy statements for Lambda role

**S3 Write Policy**:
```hcl
policy_statements = {
  s3_write = {
    effect = "Allow"
    actions = [
      "s3:PutObject",      # Upload files
      "s3:PutObjectAcl",   # Set object ACLs
      "s3:GetObject"       # Generate presigned URLs
    ]
    resources = ["arn:aws:s3:::bucket-name/*"]
  }
}
```

**Least Privilege Principle**:
- ✅ Only actions needed
- ✅ Specific bucket ARN
- ✅ No wildcard permissions
- ❌ No `s3:*` or `s3:DeleteObject`

### CloudWatch Logs

#### `attach_cloudwatch_logs_policy`
- **Type**: `bool`
- **Description**: Attach policy for CloudWatch Logs
- **Default**: `false`
- **Set to**: `true` (for logging)

#### `cloudwatch_logs_retention_in_days`
- **Type**: `number`
- **Description**: How long to keep logs
- **Options**: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
- **Default**: Never expire
- **Recommendation**: 7-30 days for cost optimization
- **Cost**: $0.50 per GB stored

### API Gateway Integration

#### `allowed_triggers`
- **Type**: `map(object)`
- **Description**: Services allowed to invoke Lambda
- **Purpose**: Creates resource-based policy

**API Gateway Trigger**:
```hcl
allowed_triggers = {
  APIGatewayAny = {
    service    = "apigateway"
    source_arn = "${api_gateway_arn}/*/*"
  }
}
```

**ARN Format**: `arn:aws:execute-api:region:account:api-id/*/*`
- First `*`: Stage (any stage)
- Second `*`: Route (any route)

---

## Lambda Function Code

### File Structure

```
lambda/
└── lambda_function.py
```

### Handler Function

```python
def lambda_handler(event, context):
    """
    Entry point for Lambda execution.
    
    Args:
        event: API Gateway event (HTTP API v2 format)
        context: Lambda context object
        
    Returns:
        dict: HTTP response
    """
```

### Event Structure (HTTP API v2)

```json
{
  "version": "2.0",
  "routeKey": "GET /upload",
  "rawPath": "/upload",
  "requestContext": {
    "http": {
      "method": "GET",
      "path": "/upload"
    }
  },
  "queryStringParameters": {
    "filename": "document.pdf",
    "contentType": "application/pdf"
  },
  "body": "base64-encoded-content",
  "isBase64Encoded": true
}
```

### Response Structure

```python
return {
    'statusCode': 200,
    'headers': {
        'Content-Type': 'application/json'
    },
    'body': json.dumps({
        'message': 'Success',
        'data': {...}
    })
}
```

---

## Performance Optimization

### Cold Start Optimization

**Cold Start**: First invocation after deployment or idle period

**Typical Cold Start Times**:
- Python 3.11: 200-400ms
- With dependencies: 500-1000ms

**Optimization Strategies**:

1. **Minimize Dependencies**:
```python
# ❌ Bad: Import everything
import boto3
import json
import base64
import uuid
from datetime import datetime

# ✅ Good: Import only what's needed
from boto3 import client
from json import dumps
```

2. **Initialize Outside Handler**:
```python
# ✅ Good: Reused across invocations
s3_client = boto3.client('s3')

def lambda_handler(event, context):
    # Use s3_client here
```

3. **Use Provisioned Concurrency** (for high-traffic):
```hcl
provisioned_concurrent_executions = 5
```

### Memory vs Cost Trade-off

| Memory | vCPU | Duration (6MB upload) | Cost per 1M requests |
|--------|------|----------------------|----------------------|
| 128 MB | 0.08 | 3000ms | $6.25 |
| 256 MB | 0.17 | 1500ms | $6.25 |
| 512 MB | 0.33 | 800ms | $6.67 |
| 1024 MB | 0.67 | 400ms | $6.67 |

**Sweet Spot**: 256 MB (good balance)

---

## Error Handling

### Lambda Errors

**Types**:
1. **Function Errors**: Exceptions in code
2. **Runtime Errors**: Python runtime issues
3. **Timeout Errors**: Execution exceeds timeout
4. **Memory Errors**: Out of memory

**Handling**:
```python
try:
    # Upload logic
    result = s3_client.put_object(...)
except ClientError as e:
    error_code = e.response['Error']['Code']
    if error_code == 'NoSuchBucket':
        return error_response(500, 'Bucket not found')
    elif error_code == 'AccessDenied':
        return error_response(500, 'Access denied')
    else:
        return error_response(500, 'Upload failed')
except Exception as e:
    print(f"ERROR: {str(e)}")
    return error_response(500, 'Internal error')
```

### Retry Behavior

**Synchronous Invocation** (API Gateway):
- No automatic retries
- Client must retry

**Asynchronous Invocation**:
- 2 automatic retries
- Dead Letter Queue (DLQ) for failures

---

## Monitoring

### CloudWatch Metrics

**Invocation Metrics**:
- `Invocations`: Total invocations
- `Errors`: Function errors
- `Throttles`: Concurrent execution limit reached
- `Duration`: Execution time
- `ConcurrentExecutions`: Concurrent invocations

**Alarms to Create**:
```hcl
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "lambda-upload-handler-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Lambda function error rate too high"
}
```

### CloudWatch Logs

**Log Format**:
```
START RequestId: abc-123 Version: $LATEST
SUCCESS: Generated presigned URL for uploads/file.pdf
END RequestId: abc-123
REPORT RequestId: abc-123 Duration: 145.67 ms Billed Duration: 146 ms Memory Size: 256 MB Max Memory Used: 67 MB
```

**Useful Log Insights Queries**:

```sql
-- Find errors
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc

-- Average duration
stats avg(@duration) by bin(5m)

-- Memory usage
stats max(@maxMemoryUsed / 1024 / 1024) as maxMemoryMB by bin(5m)
```

---

## Limitations

### Execution Limits
- **Timeout**: Max 15 minutes (900 seconds)
- **Memory**: Max 10,240 MB
- **Ephemeral Storage**: 512 MB - 10,240 MB
- **Payload**: 6 MB synchronous, 256 KB asynchronous
- **Environment Variables**: 4 KB total

### Concurrency Limits
- **Account Limit**: 1,000 concurrent executions (default)
- **Reserved Concurrency**: Can reserve for specific function
- **Provisioned Concurrency**: Pre-warmed instances (extra cost)

### Deployment Limits
- **Package Size**: 50 MB (zipped), 250 MB (unzipped)
- **Layers**: Max 5 layers per function
- **Total Size**: 250 MB (code + layers)

---

## Best Practices

### 1. Code Organization
```python
# ✅ Good structure
def lambda_handler(event, context):
    return route_request(event)

def route_request(event):
    method = get_http_method(event)
    if method == 'GET':
        return generate_presigned_url(event)
    elif method == 'POST':
        return handle_direct_upload(event)
```

### 2. Error Logging
```python
# ✅ Good: Structured logging
print(f"ERROR: {error_type} - {error_message}")

# ❌ Bad: Generic logging
print("Error occurred")
```

### 3. Environment Variables
```python
# ✅ Good: Validate at startup
BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')
if not BUCKET_NAME:
    raise ValueError("S3_BUCKET_NAME not set")
```

### 4. Timeout Buffer
```python
# ✅ Good: Check remaining time
if context.get_remaining_time_in_millis() < 5000:
    return error_response(504, 'Timeout approaching')
```

---

## Next Steps

- [KB-04-API-Gateway-Module.md](KB-04-API-Gateway-Module.md) - API Gateway configuration
- [KB-05-Limitations.md](KB-05-Limitations.md) - System limitations

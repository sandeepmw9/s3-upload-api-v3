# Knowledge Base: API Gateway Module

## Module Information

**Module Source**: `terraform-aws-modules/apigateway-v2/aws`
**Version**: ~> 5.0
**Registry**: https://registry.terraform.io/modules/terraform-aws-modules/apigateway-v2/aws
**API Type**: HTTP API (v2)

---

## Purpose

Creates an HTTP API Gateway that:
- Exposes REST endpoints for file uploads
- Integrates with Lambda function
- Handles CORS for browser uploads
- Provides throttling and rate limiting

---

## HTTP API vs REST API

### Why HTTP API?

| Feature | REST API | HTTP API | Winner |
|---------|----------|----------|--------|
| **Cost** | $3.50/million | $1.00/million | HTTP (71% cheaper) |
| **Latency** | Higher | Lower | HTTP |
| **CORS** | Manual config | Native support | HTTP |
| **WebSocket** | No | Yes | HTTP |
| **API Keys** | Yes | No | REST |
| **Usage Plans** | Yes | No | REST |
| **Request Validation** | Yes | Limited | REST |

**Recommendation**: Use HTTP API for Lambda proxy integrations (our use case)

---

## Module Configuration

### Basic Configuration

```hcl
module "api_gateway" {
  source  = "terraform-aws-modules/apigateway-v2/aws"
  version = "~> 5.0"

  name          = var.api_name
  description   = "API Gateway for file uploads"
  protocol_type = "HTTP"
  
  cors_configuration = {
    allow_headers = [
      "content-type",
      "x-amz-date",
      "authorization",
      "x-api-key",
      "x-amz-security-token"
    ]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_origins = var.allowed_origins
  }
  
  routes = {
    "GET /upload" = {
      integration = {
        uri                    = module.lambda_function.lambda_function_arn
        payload_format_version = "2.0"
        timeout_milliseconds   = 30000
      }
    }
    
    "POST /upload" = {
      integration = {
        uri                    = module.lambda_function.lambda_function_arn
        payload_format_version = "2.0"
        timeout_milliseconds   = 30000
      }
    }
  }
  
  stage_name        = var.api_stage_name
  stage_auto_deploy = true
  
  stage_default_route_settings = {
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
  }
  
  tags = local.common_tags
}
```

---

## Arguments Explained

### Required Arguments

#### `name`
- **Type**: `string`
- **Description**: Name of the API Gateway
- **Constraints**: 1-128 characters
- **Example**: `"upload-api"`
- **Best Practice**: Use descriptive names

#### `protocol_type`
- **Type**: `string`
- **Options**: `"HTTP"` or `"WEBSOCKET"`
- **Our Choice**: `"HTTP"`
- **Note**: Cannot be changed after creation

### CORS Configuration

#### `cors_configuration`
- **Type**: `object`
- **Description**: Cross-Origin Resource Sharing settings
- **Required for**: Browser uploads

**Structure**:
```hcl
cors_configuration = {
  allow_headers = [...]  # Headers browser can send
  allow_methods = [...]  # HTTP methods allowed
  allow_origins = [...]  # Domains allowed
  allow_credentials = false  # Include cookies?
  expose_headers = [...]  # Headers browser can read
  max_age = 3600  # Cache preflight (seconds)
}
```

**allow_headers**:
```hcl
allow_headers = [
  "content-type",           # Required for file uploads
  "x-amz-date",            # AWS signature
  "authorization",          # Auth tokens
  "x-api-key",             # API keys (if used)
  "x-amz-security-token"   # Temporary credentials
]
```

**allow_methods**:
```hcl
allow_methods = ["GET", "POST", "OPTIONS"]
# GET: Generate presigned URL
# POST: Direct upload
# OPTIONS: CORS preflight (automatic)
```

**allow_origins**:
```hcl
# Development
allow_origins = ["*"]

# Production
allow_origins = [
  "https://myapp.com",
  "https://app.mycompany.com"
]
```

⚠️ **Security Warning**: Never use `["*"]` in production!

### Routes Configuration

#### `routes`
- **Type**: `map(object)`
- **Description**: API routes and their integrations
- **Format**: `"{METHOD} {PATH}"`

**Route Structure**:
```hcl
routes = {
  "GET /upload" = {
    integration = {
      uri                    = "arn:aws:lambda:..."
      payload_format_version = "2.0"
      timeout_milliseconds   = 30000
    }
  }
}
```

**integration.uri**:
- **Type**: `string`
- **Format**: Lambda function ARN
- **Example**: `arn:aws:lambda:us-east-1:123456789012:function:upload-handler`

**integration.payload_format_version**:
- **Type**: `string`
- **Options**: `"1.0"` or `"2.0"`
- **Our Choice**: `"2.0"` (simplified event format)
- **Difference**:

```json
// Version 1.0 (complex)
{
  "resource": "/upload",
  "path": "/upload",
  "httpMethod": "GET",
  "headers": {...},
  "queryStringParameters": {...}
}

// Version 2.0 (simplified)
{
  "version": "2.0",
  "routeKey": "GET /upload",
  "requestContext": {
    "http": {
      "method": "GET",
      "path": "/upload"
    }
  },
  "queryStringParameters": {...}
}
```

**integration.timeout_milliseconds**:
- **Type**: `number`
- **Range**: 50-30,000 ms (30 seconds max)
- **Default**: 30,000 ms
- **Recommendation**: Match Lambda timeout

### Stage Configuration

#### `stage_name`
- **Type**: `string`
- **Description**: Deployment stage name
- **Common Values**: `"dev"`, `"staging"`, `"prod"`
- **Our Default**: `"prod"`
- **URL Format**: `https://{api-id}.execute-api.{region}.amazonaws.com/{stage_name}`

#### `stage_auto_deploy`
- **Type**: `bool`
- **Description**: Automatically deploy on changes
- **Default**: `false`
- **Our Setting**: `true` (for convenience)
- **Production**: Consider `false` for manual control

#### `stage_default_route_settings`
- **Type**: `object`
- **Description**: Default settings for all routes

**Throttling Settings**:
```hcl
stage_default_route_settings = {
  throttling_burst_limit = 5000   # Burst capacity
  throttling_rate_limit  = 10000  # Requests per second
  detailed_metrics_enabled = true  # CloudWatch metrics
  logging_level = "INFO"           # Access logs
}
```

**throttling_burst_limit**:
- **Description**: Maximum concurrent requests
- **Range**: 0-10,000
- **Default**: 5,000
- **Use Case**: Handle traffic spikes

**throttling_rate_limit**:
- **Description**: Steady-state requests per second
- **Range**: 0-20,000
- **Default**: 10,000
- **Use Case**: Prevent abuse

---

## Outputs

### `api_id`
- **Type**: `string`
- **Description**: Unique API identifier
- **Format**: 10-character alphanumeric
- **Example**: `"abc123def4"`
- **Use**: Construct API URLs

### `api_endpoint`
- **Type**: `string`
- **Description**: Base URL of the API
- **Format**: `https://{api-id}.execute-api.{region}.amazonaws.com`
- **Example**: `"https://abc123def4.execute-api.us-east-1.amazonaws.com"`
- **Note**: Does not include stage name

### `api_execution_arn`
- **Type**: `string`
- **Description**: ARN for Lambda permissions
- **Format**: `arn:aws:execute-api:{region}:{account}:{api-id}`
- **Use**: Lambda resource-based policy

### `stage_invoke_url`
- **Type**: `string`
- **Description**: Full URL including stage
- **Format**: `https://{api-id}.execute-api.{region}.amazonaws.com/{stage}`
- **Example**: `"https://abc123def4.execute-api.us-east-1.amazonaws.com/prod"`
- **Use**: Client applications

---

## Request/Response Flow

### Request Flow

```
1. Client Request
   GET https://api-id.execute-api.us-east-1.amazonaws.com/prod/upload?filename=test.pdf
   │
   ▼
2. API Gateway
   • Validates request
   • Checks throttling limits
   • Applies CORS headers
   │
   ▼
3. Lambda Integration
   • Transforms to Lambda event format (v2.0)
   • Invokes Lambda function
   • Waits for response (max 30s)
   │
   ▼
4. Lambda Function
   • Processes request
   • Returns response
   │
   ▼
5. API Gateway
   • Transforms Lambda response
   • Adds CORS headers
   • Returns to client
```

### Event Transformation

**API Gateway → Lambda**:
```json
{
  "version": "2.0",
  "routeKey": "GET /upload",
  "rawPath": "/prod/upload",
  "rawQueryString": "filename=test.pdf",
  "headers": {
    "accept": "application/json",
    "content-type": "application/json",
    "host": "abc123.execute-api.us-east-1.amazonaws.com",
    "user-agent": "Mozilla/5.0..."
  },
  "queryStringParameters": {
    "filename": "test.pdf"
  },
  "requestContext": {
    "accountId": "123456789012",
    "apiId": "abc123",
    "domainName": "abc123.execute-api.us-east-1.amazonaws.com",
    "http": {
      "method": "GET",
      "path": "/prod/upload",
      "protocol": "HTTP/1.1",
      "sourceIp": "1.2.3.4",
      "userAgent": "Mozilla/5.0..."
    },
    "requestId": "abc-123-def",
    "routeKey": "GET /upload",
    "stage": "prod",
    "time": "20/Feb/2024:12:34:56 +0000",
    "timeEpoch": 1708435696000
  },
  "isBase64Encoded": false
}
```

**Lambda → API Gateway**:
```json
{
  "statusCode": 200,
  "headers": {
    "Content-Type": "application/json"
  },
  "body": "{\"message\":\"Success\"}"
}
```

---

## Throttling Deep Dive

### How Throttling Works

**Token Bucket Algorithm**:
1. Bucket starts with `burst_limit` tokens
2. Tokens refill at `rate_limit` per second
3. Each request consumes 1 token
4. If no tokens available, request is throttled (429 error)

**Example**:
```
burst_limit = 5000
rate_limit = 10000

Scenario 1: Sudden spike
- 5000 requests arrive instantly → All succeed (burst)
- Next 5000 requests → Throttled (bucket empty)
- After 0.5 seconds → 5000 tokens refilled
- Next 5000 requests → Succeed

Scenario 2: Steady traffic
- 10000 requests per second → All succeed
- 15000 requests per second → 5000 throttled
```

### Throttling Errors

**Response**:
```json
{
  "message": "Too Many Requests"
}
```

**Status Code**: 429

**Headers**:
```
Retry-After: 1
X-Amzn-ErrorType: TooManyRequestsException
```

### Handling Throttling

**Client-Side Retry**:
```javascript
async function uploadWithRetry(url, data, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      const response = await fetch(url, {
        method: 'POST',
        body: data
      });
      
      if (response.status === 429) {
        const retryAfter = response.headers.get('Retry-After') || 1;
        await sleep(retryAfter * 1000);
        continue;
      }
      
      return response;
    } catch (error) {
      if (i === maxRetries - 1) throw error;
    }
  }
}
```

---

## Monitoring

### CloudWatch Metrics

**Request Metrics**:
- `Count`: Total requests
- `IntegrationLatency`: Lambda execution time
- `Latency`: Total request time
- `4XXError`: Client errors
- `5XXError`: Server errors

**Metric Dimensions**:
- `ApiId`: Specific API
- `Stage`: Deployment stage
- `Route`: Specific route

**Useful Alarms**:
```hcl
resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  alarm_name          = "api-gateway-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  
  dimensions = {
    ApiId = module.api_gateway.api_id
    Stage = var.api_stage_name
  }
}
```

### Access Logging

**Enable Logging**:
```hcl
stage_access_log_settings = {
  destination_arn = aws_cloudwatch_log_group.api_gateway.arn
  format = jsonencode({
    requestId      = "$context.requestId"
    ip             = "$context.identity.sourceIp"
    requestTime    = "$context.requestTime"
    httpMethod     = "$context.httpMethod"
    routeKey       = "$context.routeKey"
    status         = "$context.status"
    protocol       = "$context.protocol"
    responseLength = "$context.responseLength"
    integrationLatency = "$context.integrationLatency"
  })
}
```

**Log Example**:
```json
{
  "requestId": "abc-123",
  "ip": "1.2.3.4",
  "requestTime": "20/Feb/2024:12:34:56 +0000",
  "httpMethod": "POST",
  "routeKey": "POST /upload",
  "status": "200",
  "protocol": "HTTP/1.1",
  "responseLength": "156",
  "integrationLatency": "145"
}
```

---

## Security Best Practices

### 1. CORS Configuration
```hcl
# ❌ Bad: Allow all origins in production
allow_origins = ["*"]

# ✅ Good: Specific domains
allow_origins = [
  "https://myapp.com",
  "https://app.mycompany.com"
]
```

### 2. Throttling
```hcl
# ✅ Good: Set reasonable limits
throttling_burst_limit = 5000
throttling_rate_limit  = 10000

# Monitor and adjust based on traffic
```

### 3. Custom Domain
```hcl
# ✅ Good: Use custom domain
domain_name = "api.mycompany.com"

# Instead of:
# abc123.execute-api.us-east-1.amazonaws.com
```

### 4. WAF Integration
```hcl
# ✅ Good: Add WAF for DDoS protection
resource "aws_wafv2_web_acl_association" "api" {
  resource_arn = module.api_gateway.api_arn
  web_acl_arn  = aws_wafv2_web_acl.api.arn
}
```

---

## Limitations

### HTTP API Limitations
- No API keys
- No usage plans
- No request/response transformation
- No caching
- Limited request validation

### Request Limits
- **Payload Size**: 10 MB
- **Timeout**: 30 seconds
- **Header Size**: 10 KB
- **Query String**: 10 KB

### Rate Limits
- **Burst**: Max 10,000
- **Rate**: Max 20,000 RPS
- **Account Limit**: Shared across all APIs

---

## Cost Optimization

### Pricing
- **HTTP API**: $1.00 per million requests
- **REST API**: $3.50 per million requests
- **Data Transfer**: $0.09 per GB (out)

### Cost Example
```
Monthly Traffic: 10 million requests
Average Response: 1 KB

HTTP API Cost:
- Requests: 10M × $1.00/M = $10.00
- Data Transfer: 10GB × $0.09 = $0.90
- Total: $10.90/month

REST API Cost:
- Requests: 10M × $3.50/M = $35.00
- Data Transfer: 10GB × $0.09 = $0.90
- Total: $35.90/month

Savings: $25.00/month (70% cheaper)
```

---

## Next Steps

- [KB-05-Limitations.md](KB-05-Limitations.md) - System limitations
- [KB-06-Troubleshooting.md](KB-06-Troubleshooting.md) - Common issues

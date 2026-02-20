# Knowledge Base: Limitations & Constraints

## System-Wide Limitations

### File Size Limits

| Upload Method | Maximum Size | Constraint | Workaround |
|---------------|--------------|------------|------------|
| **Direct POST** | 6 MB | Lambda synchronous payload | Use presigned URL |
| **Presigned URL** | 5 GB | S3 single PUT operation | Use multipart upload |
| **Multipart Upload** | 5 TB | S3 maximum object size | Split into multiple objects |

**Why 6 MB for Direct Upload?**
```
API Gateway payload limit: 10 MB
Base64 encoding overhead: ~33%
Effective limit: 10 MB / 1.33 = 7.5 MB
Safe limit with headers: 6 MB
```

---

## AWS Service Limits

### API Gateway Limits

#### HTTP API (Our Choice)

| Resource | Limit | Adjustable | Notes |
|----------|-------|------------|-------|
| **Payload Size** | 10 MB | No | Hard limit |
| **Timeout** | 30 seconds | No | Hard limit |
| **Throttle Burst** | 10,000 | Yes | Per account |
| **Throttle Rate** | 20,000 RPS | Yes | Per account |
| **Routes per API** | 300 | Yes | Contact AWS |
| **Integrations per Route** | 1 | No | Hard limit |
| **Stages per API** | 10 | Yes | Contact AWS |
| **Custom Domains** | 120 | Yes | Per account |

#### REST API (Alternative)

| Resource | Limit | Adjustable | Notes |
|----------|-------|------------|-------|
| **Payload Size** | 10 MB | No | Hard limit |
| **Timeout** | 29 seconds | No | Hard limit |
| **Throttle Burst** | 5,000 | Yes | Per account |
| **Throttle Rate** | 10,000 RPS | Yes | Per account |
| **API Keys** | 500 | Yes | Per account |
| **Usage Plans** | 300 | Yes | Per account |

**Request Limit Increase**:
```bash
# Check current limits
aws service-quotas get-service-quota \
  --service-code apigateway \
  --quota-code L-A93EF0EB

# Request increase
aws service-quotas request-service-quota-increase \
  --service-code apigateway \
  --quota-code L-A93EF0EB \
  --desired-value 50000
```

### Lambda Limits

#### Function Configuration

| Resource | Limit | Adjustable | Notes |
|----------|-------|------------|-------|
| **Memory** | 128 MB - 10,240 MB | No | Hard limit |
| **Timeout** | 15 minutes (900s) | No | Hard limit |
| **Ephemeral Storage** | 512 MB - 10,240 MB | No | Hard limit |
| **Environment Variables** | 4 KB | No | Hard limit |
| **Deployment Package** | 50 MB (zipped) | No | Hard limit |
| **Deployment Package** | 250 MB (unzipped) | No | Hard limit |
| **Layers** | 5 per function | No | Hard limit |
| **Total Size** | 250 MB (code + layers) | No | Hard limit |

#### Invocation Limits

| Resource | Limit | Adjustable | Notes |
|----------|-------|------------|-------|
| **Concurrent Executions** | 1,000 | Yes | Per account/region |
| **Synchronous Payload** | 6 MB | No | Hard limit |
| **Asynchronous Payload** | 256 KB | No | Hard limit |
| **Invocation Frequency** | Unlimited | - | Pay per use |

**Concurrency Calculation**:
```
Concurrent Executions = (Requests per Second) × (Average Duration in Seconds)

Example:
- 100 requests/second
- 2 seconds average duration
- Concurrent executions = 100 × 2 = 200

If limit is 1,000, you can handle:
1,000 / 2 = 500 requests/second
```

**Request Concurrency Increase**:
```bash
# Check current limit
aws service-quotas get-service-quota \
  --service-code lambda \
  --quota-code L-B99A9384

# Request increase
aws service-quotas request-service-quota-increase \
  --service-code lambda \
  --quota-code L-B99A9384 \
  --desired-value 5000
```

### S3 Limits

#### Bucket Limits

| Resource | Limit | Adjustable | Notes |
|----------|-------|------------|-------|
| **Buckets per Account** | 100 | Yes | Soft limit |
| **Bucket Name Length** | 3-63 characters | No | Hard limit |
| **Objects per Bucket** | Unlimited | - | No limit |
| **Object Size** | 5 TB | No | Hard limit |
| **Single PUT** | 5 GB | No | Use multipart |
| **Multipart Parts** | 10,000 | No | Hard limit |

#### Performance Limits

| Operation | Limit | Notes |
|-----------|-------|-------|
| **PUT/COPY/POST/DELETE** | 3,500 RPS | Per prefix |
| **GET/HEAD** | 5,500 RPS | Per prefix |
| **LIST** | 3,500 RPS | Per bucket |

**Prefix Strategy for High Throughput**:
```
# Bad: All files in one prefix
uploads/file1.pdf
uploads/file2.pdf
uploads/file3.pdf
Limit: 3,500 PUT/s

# Good: Distribute across prefixes
uploads/a/file1.pdf
uploads/b/file2.pdf
uploads/c/file3.pdf
Limit: 3,500 × 3 = 10,500 PUT/s
```

---

## Terraform Module Limitations

### S3 Bucket Module

**Cannot Configure**:
- ❌ Object Lock (requires separate resource)
- ❌ Replication (requires separate resource)
- ❌ Inventory (requires separate resource)
- ❌ Analytics (requires separate resource)

**Workaround**:
```hcl
# Add after module
resource "aws_s3_bucket_object_lock_configuration" "this" {
  bucket = module.s3_bucket.bucket_name
  
  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = 30
    }
  }
}
```

### Lambda Module

**Cannot Configure**:
- ❌ VPC configuration (requires additional arguments)
- ❌ File system mounts (EFS)
- ❌ Code signing
- ❌ Image-based functions (only ZIP supported)

**VPC Configuration**:
```hcl
module "lambda_function" {
  # ... other config
  
  vpc_subnet_ids         = var.subnet_ids
  vpc_security_group_ids = var.security_group_ids
  attach_network_policy  = true
}
```

### API Gateway Module

**Cannot Configure**:
- ❌ Request/response transformation
- ❌ API caching (HTTP API doesn't support)
- ❌ API keys (HTTP API doesn't support)
- ❌ Usage plans (HTTP API doesn't support)

**Workaround**: Use REST API module if needed
```hcl
module "api_gateway" {
  source = "terraform-aws-modules/apigateway-v1/aws"  # REST API
  # ... config
}
```

---

## Browser Limitations

### File Upload Constraints

**Browser Memory**:
- **Chrome**: ~2 GB per tab
- **Firefox**: ~2 GB per tab
- **Safari**: ~1 GB per tab
- **Mobile**: ~500 MB

**Recommendation**: Use presigned URL for files > 100 MB

### CORS Restrictions

**Same-Origin Policy**:
```javascript
// ❌ Blocked: Different origin
fetch('https://api.example.com/upload', {
  method: 'POST',
  body: file
});
// Error: CORS policy blocks request

// ✅ Allowed: CORS configured
// Server must return:
// Access-Control-Allow-Origin: https://myapp.com
```

**Credentials with Wildcards**:
```hcl
# ❌ Invalid: Cannot use * with credentials
cors_configuration = {
  allow_origins = ["*"]
  allow_credentials = true  # Error!
}

# ✅ Valid: Specific origins with credentials
cors_configuration = {
  allow_origins = ["https://myapp.com"]
  allow_credentials = true
}
```

### JavaScript Limitations

**File API**:
```javascript
// ❌ Cannot read file path
const path = file.path;  // undefined

// ✅ Can read file content
const reader = new FileReader();
reader.readAsArrayBuffer(file);
```

**Progress Tracking**:
```javascript
// ✅ Works: XMLHttpRequest
const xhr = new XMLHttpRequest();
xhr.upload.addEventListener('progress', (e) => {
  const percent = (e.loaded / e.total) * 100;
});

// ❌ Limited: Fetch API
// No upload progress events
```

---

## Network Limitations

### Bandwidth Constraints

**Upload Speed**:
```
Connection Type | Typical Upload Speed | 100 MB Upload Time
----------------|---------------------|-------------------
4G Mobile       | 5-10 Mbps          | 80-160 seconds
Home Broadband  | 10-50 Mbps         | 16-80 seconds
Fiber           | 100-1000 Mbps      | 0.8-8 seconds
```

**Timeout Considerations**:
```
Lambda timeout: 30 seconds
API Gateway timeout: 30 seconds

Maximum file size for direct upload:
30 seconds × 5 Mbps = 18.75 MB (theoretical)
Safe limit: 6 MB (accounts for processing time)
```

### Connection Stability

**Mobile Networks**:
- Frequent disconnections
- Variable bandwidth
- High latency

**Recommendation**: 
- Use presigned URL (resumable)
- Implement retry logic
- Show progress indicator

---

## Security Limitations

### Presigned URL Constraints

**Expiration**:
- **Minimum**: 1 second
- **Maximum**: 7 days (604,800 seconds)
- **Recommendation**: 1 hour (3,600 seconds)

**Cannot Revoke**:
```
Once generated, presigned URL is valid until expiration.
Cannot be revoked early.

Workaround: Use short expiration times
```

**No User Authentication**:
```
Presigned URL grants access to anyone with the URL.
No way to verify user identity.

Workaround: Generate URL per authenticated user
```

### IAM Policy Limitations

**Policy Size**:
- **Inline Policy**: 2,048 characters
- **Managed Policy**: 6,144 characters
- **Total Policies**: 10 per role

**Workaround**:
```hcl
# Use managed policies for common permissions
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Use inline policies for specific permissions
resource "aws_iam_role_policy" "s3_write" {
  name = "s3-write"
  role = aws_iam_role.lambda.id
  policy = jsonencode({...})
}
```

---

## Cost Limitations

### Free Tier Limits

**API Gateway**:
- **HTTP API**: 1 million requests/month (12 months)
- **REST API**: 1 million requests/month (12 months)

**Lambda**:
- **Requests**: 1 million/month (always free)
- **Compute**: 400,000 GB-seconds/month (always free)

**S3**:
- **Storage**: 5 GB (12 months)
- **PUT Requests**: 2,000 (12 months)
- **GET Requests**: 20,000 (12 months)

### Cost Scaling

**Example: 1 million uploads/month (50 MB each)**

```
API Gateway HTTP:
- Requests: 1M × $1.00/M = $1.00

Lambda (256 MB, 2s avg):
- Requests: 1M × $0.20/M = $0.20
- Compute: 1M × 2s × 256MB × $0.0000166667 = $8.53
- Total: $8.73

S3:
- Storage: 50 TB × $0.023/GB = $1,177.60
- PUT: 1M × $0.005/1000 = $5.00
- Total: $1,182.60

Total Monthly Cost: $1,192.33
```

**Cost Optimization**:
1. Use presigned URLs (reduce Lambda invocations)
2. Implement S3 lifecycle policies
3. Use S3 Intelligent-Tiering
4. Monitor and set billing alarms

---

## Operational Limitations

### Deployment Constraints

**Terraform State**:
- **Size Limit**: 10 MB (S3 backend)
- **Locking**: DynamoDB required
- **Concurrent Operations**: 1 (with locking)

**Module Updates**:
```bash
# Cannot update module version without re-init
terraform init -upgrade

# May require resource replacement
terraform plan  # Check for replacements
```

### Monitoring Limitations

**CloudWatch Logs**:
- **Retention**: Max 10 years
- **Query Limit**: 10,000 log events
- **Insights**: 1 MB query result limit

**CloudWatch Metrics**:
- **Retention**: 15 months
- **Resolution**: 1 minute (standard), 1 second (high-res)
- **Alarms**: 5,000 per region

---

## Workarounds Summary

| Limitation | Workaround |
|------------|------------|
| 6 MB direct upload | Use presigned URL |
| 5 GB presigned upload | Implement multipart upload |
| Lambda timeout | Use Step Functions for long processes |
| API Gateway timeout | Use async invocation |
| S3 3,500 PUT/s | Use multiple prefixes |
| Lambda concurrency | Request limit increase |
| No API keys (HTTP API) | Use Lambda authorizer |
| Cannot revoke presigned URL | Use short expiration |
| Browser memory limit | Stream upload in chunks |

---

## Next Steps

- [KB-06-Troubleshooting.md](KB-06-Troubleshooting.md) - Common issues and solutions
- [KB-01-Overview.md](KB-01-Overview.md) - Back to overview

# Knowledge Base: Troubleshooting Guide

## Common Issues and Solutions

---

## Issue 1: CORS Errors in Browser

### Symptoms
```
Access to fetch at 'https://api-id.execute-api.us-east-1.amazonaws.com/prod/upload'
from origin 'https://myapp.com' has been blocked by CORS policy:
No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

### Root Causes

#### Cause 1: CORS Not Configured
**Check**:
```hcl
# In main.tf
cors_configuration = {
  allow_origins = var.allowed_origins
}
```

**Fix**:
```hcl
cors_configuration = {
  allow_headers = ["content-type", "x-amz-date", "authorization"]
  allow_methods = ["GET", "POST", "OPTIONS"]
  allow_origins = ["https://myapp.com"]
}
```

#### Cause 2: Origin Not in Allowed List
**Check**:
```bash
# Current origin
echo "https://myapp.com"

# Allowed origins in terraform.tfvars
allowed_origins = ["https://otherapp.com"]  # Wrong!
```

**Fix**:
```hcl
allowed_origins = ["https://myapp.com"]
```

#### Cause 3: Using Wildcard with Credentials
**Check**:
```javascript
// Browser request
fetch(url, {
  credentials: 'include',  // Sending cookies
  method: 'POST'
});
```

**Fix**:
```hcl
# Cannot use * with credentials
cors_configuration = {
  allow_origins = ["https://myapp.com"]  # Specific domain
  allow_credentials = false  # Or remove credentials from request
}
```

### Verification

**Test CORS**:
```bash
curl -X OPTIONS \
  -H "Origin: https://myapp.com" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: content-type" \
  -v \
  https://api-id.execute-api.us-east-1.amazonaws.com/prod/upload
```

**Expected Response**:
```
HTTP/2 200
access-control-allow-origin: https://myapp.com
access-control-allow-methods: GET,POST,OPTIONS
access-control-allow-headers: content-type,x-amz-date,authorization
```

---

## Issue 2: 413 Payload Too Large

### Symptoms
```json
{
  "message": "Payload Too Large"
}
```

### Root Causes

#### Cause 1: File Exceeds 6 MB (Direct Upload)
**Check**:
```javascript
console.log('File size:', file.size / 1024 / 1024, 'MB');
// Output: File size: 8.5 MB
```

**Fix**: Use presigned URL instead
```javascript
// Get presigned URL
const response = await fetch(
  `${API_ENDPOINT}?filename=${file.name}&contentType=${file.type}&maxSize=${100*1024*1024}`
);
const { uploadUrl, fields } = await response.json();

// Upload directly to S3
const formData = new FormData();
Object.keys(fields).forEach(key => formData.append(key, fields[key]));
formData.append('file', file);

await fetch(uploadUrl, {
  method: 'POST',
  body: formData
});
```

#### Cause 2: Base64 Encoding Overhead
**Check**:
```javascript
// Original file: 5 MB
// Base64 encoded: 5 MB × 1.33 = 6.65 MB (exceeds 6 MB limit)
```

**Fix**: Use presigned URL for files > 4.5 MB

### Prevention

**Client-Side Check**:
```javascript
const MAX_DIRECT_UPLOAD = 6 * 1024 * 1024;  // 6 MB

if (file.size > MAX_DIRECT_UPLOAD) {
  // Use presigned URL
  await uploadViaPresignedUrl(file);
} else {
  // Direct upload
  await uploadDirectly(file);
}
```

---

## Issue 3: Lambda Timeout

### Symptoms
```json
{
  "message": "Endpoint request timed out"
}
```

### Root Causes

#### Cause 1: File Too Large for Direct Upload
**Check CloudWatch Logs**:
```
REPORT RequestId: abc-123
Duration: 30000.00 ms
Billed Duration: 30000 ms
```

**Fix**: Increase timeout or use presigned URL
```hcl
# In variables.tf
lambda_timeout = 60  # Increase to 60 seconds

# Or use presigned URL for large files
```

#### Cause 2: S3 Upload Slow
**Check**:
```python
import time
start = time.time()
s3_client.put_object(Bucket=bucket, Key=key, Body=content)
duration = time.time() - start
print(f"S3 upload took {duration} seconds")
```

**Fix**: Optimize network or use presigned URL

#### Cause 3: Cold Start
**Check CloudWatch Logs**:
```
REPORT RequestId: abc-123
Init Duration: 2500.00 ms  # Cold start
Duration: 28000.00 ms
Total: 30500.00 ms  # Exceeds 30s timeout
```

**Fix**: Use provisioned concurrency
```hcl
provisioned_concurrent_executions = 2
```

### Prevention

**Set Appropriate Timeout**:
```hcl
# Calculate required timeout
# File size: 6 MB
# Upload speed: 1 MB/s
# Processing: 2s
# Buffer: 5s
# Total: 6 + 2 + 5 = 13s

lambda_timeout = 15  # Add buffer
```

---

## Issue 4: 403 Forbidden (S3)

### Symptoms
```
An error occurred (AccessDenied) when calling the PutObject operation:
Access Denied
```

### Root Causes

#### Cause 1: Missing IAM Permissions
**Check Lambda Role**:
```bash
aws iam get-role-policy \
  --role-name upload-handler-execution-role \
  --policy-name s3-write
```

**Fix**:
```hcl
policy_statements = {
  s3_write = {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = ["${module.s3_bucket.bucket_arn}/*"]
  }
}
```

#### Cause 2: Bucket Policy Blocks Access
**Check Bucket Policy**:
```bash
aws s3api get-bucket-policy --bucket my-bucket
```

**Fix**: Remove restrictive bucket policy or add Lambda role

#### Cause 3: Wrong Bucket Name
**Check Environment Variable**:
```python
bucket_name = os.environ.get('S3_BUCKET_NAME')
print(f"Bucket: {bucket_name}")
# Output: Bucket: wrong-bucket-name
```

**Fix**:
```hcl
environment_variables = {
  S3_BUCKET_NAME = module.s3_bucket.bucket_name  # Correct reference
}
```

### Verification

**Test IAM Permissions**:
```bash
# Assume Lambda role
aws sts assume-role \
  --role-arn arn:aws:iam::123456789012:role/upload-handler-execution-role \
  --role-session-name test

# Try S3 upload
aws s3 cp test.pdf s3://my-bucket/test.pdf
```

---

## Issue 5: Invalid PDF Error

### Symptoms
```json
{
  "error": "File is not a valid PDF"
}
```

### Root Causes

#### Cause 1: File Not Base64 Encoded
**Check Request**:
```javascript
// ❌ Wrong: Sending raw file
fetch(url, {
  method: 'POST',
  body: file
});

// ✅ Correct: Base64 encode
const reader = new FileReader();
reader.readAsDataURL(file);
reader.onload = () => {
  const base64 = reader.result.split(',')[1];
  fetch(url, {
    method: 'POST',
    body: base64
  });
};
```

#### Cause 2: Incorrect Content-Type
**Check**:
```javascript
fetch(url, {
  method: 'POST',
  headers: {
    'Content-Type': 'text/plain'  // Wrong!
  },
  body: base64Content
});
```

**Fix**:
```javascript
headers: {
  'Content-Type': 'application/pdf'
}
```

#### Cause 3: File Corrupted During Upload
**Check**:
```python
# In Lambda
print(f"First 4 bytes: {file_content[:4]}")
# Output: b'%PDF' (correct)
# Output: b'\x00\x00\x00\x00' (corrupted)
```

**Fix**: Verify base64 encoding/decoding

### Verification

**Test Locally**:
```python
import base64

# Encode
with open('test.pdf', 'rb') as f:
    content = f.read()
    encoded = base64.b64encode(content).decode('utf-8')

# Decode
decoded = base64.b64decode(encoded)

# Verify
assert decoded[:4] == b'%PDF'
print("PDF validation passed")
```

---

## Issue 6: Presigned URL Expired

### Symptoms
```xml
<Error>
  <Code>AccessDenied</Code>
  <Message>Request has expired</Message>
</Error>
```

### Root Causes

#### Cause 1: URL Expired
**Check**:
```javascript
const expiresIn = 3600;  // 1 hour
const generatedAt = Date.now();
const expiresAt = generatedAt + (expiresIn * 1000);

if (Date.now() > expiresAt) {
  console.log('URL expired');
}
```

**Fix**: Generate new presigned URL
```javascript
// Regenerate before upload
const response = await fetch(`${API_ENDPOINT}?filename=${file.name}`);
const { uploadUrl, fields } = await response.json();
```

#### Cause 2: Clock Skew
**Check**:
```bash
# Check system time
date

# Check AWS time
aws s3 ls  # If this works, clock is correct
```

**Fix**: Sync system clock
```bash
# Linux
sudo ntpdate -s time.nist.gov

# Windows
w32tm /resync
```

### Prevention

**Set Appropriate Expiry**:
```hcl
# Short expiry for security
presigned_url_expiry = 3600  # 1 hour

# Longer for slow connections
presigned_url_expiry = 7200  # 2 hours
```

**Client-Side Validation**:
```javascript
function isUrlExpired(expiresIn, generatedAt) {
  const expiresAt = generatedAt + (expiresIn * 1000);
  const bufferTime = 60 * 1000;  // 1 minute buffer
  return Date.now() > (expiresAt - bufferTime);
}

if (isUrlExpired(data.expiresIn, Date.now())) {
  // Regenerate URL
}
```

---

## Issue 7: Terraform Apply Fails

### Symptoms
```
Error: error creating API Gateway v2 API: BadRequestException:
The resource already exists
```

### Root Causes

#### Cause 1: Resource Already Exists
**Check**:
```bash
# List existing APIs
aws apigatewayv2 get-apis

# Check if name conflicts
```

**Fix**: Use unique names or import existing resource
```bash
# Import existing resource
terraform import module.api_gateway.aws_apigatewayv2_api.this abc123

# Or change name
api_name = "upload-api-v2"
```

#### Cause 2: State Out of Sync
**Check**:
```bash
terraform state list
```

**Fix**: Refresh state
```bash
terraform refresh
terraform plan
```

#### Cause 3: Module Version Conflict
**Check**:
```bash
terraform init -upgrade
```

**Fix**: Lock module versions
```hcl
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.1.0"  # Specific version
}
```

### Prevention

**Use Remote State**:
```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "s3-upload-api/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
    dynamodb_table = "terraform-locks"
  }
}
```

---

## Issue 8: High Costs

### Symptoms
```
AWS Bill: $500/month
Expected: $50/month
```

### Root Causes

#### Cause 1: S3 Storage Growing
**Check**:
```bash
aws s3 ls s3://my-bucket --recursive --summarize
# Total Objects: 100000
# Total Size: 5000 GB
```

**Fix**: Implement lifecycle policy
```hcl
lifecycle_rule = [
  {
    id      = "delete-old-files"
    enabled = true
    
    expiration = {
      days = 90
    }
    
    noncurrent_version_expiration = {
      days = 30
    }
  }
]
```

#### Cause 2: CloudWatch Logs Not Expiring
**Check**:
```bash
aws logs describe-log-groups \
  --log-group-name-prefix /aws/lambda/upload-handler
```

**Fix**: Set retention
```hcl
cloudwatch_logs_retention_in_days = 7
```

#### Cause 3: Unused Resources
**Check**:
```bash
# Find unused APIs
aws apigatewayv2 get-apis

# Find unused Lambda functions
aws lambda list-functions
```

**Fix**: Delete unused resources
```bash
terraform destroy
```

### Prevention

**Set Billing Alarms**:
```hcl
resource "aws_cloudwatch_metric_alarm" "billing" {
  alarm_name          = "billing-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "21600"  # 6 hours
  statistic           = "Maximum"
  threshold           = "100"  # $100
  alarm_description   = "Billing exceeded $100"
}
```

---

## Debugging Tools

### CloudWatch Logs Insights

**Find Errors**:
```sql
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
```

**Analyze Performance**:
```sql
fields @timestamp, @duration
| stats avg(@duration), max(@duration), min(@duration)
| sort @timestamp desc
```

**Track Uploads**:
```sql
fields @timestamp, @message
| filter @message like /SUCCESS/
| parse @message "SUCCESS: * for *" as action, filename
| stats count() by filename
```

### AWS X-Ray

**Enable Tracing**:
```hcl
tracing_config = {
  mode = "Active"
}
```

**View Traces**:
```bash
aws xray get-trace-summaries \
  --start-time $(date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s)
```

### Local Testing

**Test Lambda Locally**:
```bash
# Install SAM CLI
pip install aws-sam-cli

# Create test event
cat > event.json <<EOF
{
  "requestContext": {
    "http": {
      "method": "GET"
    }
  },
  "queryStringParameters": {
    "filename": "test.pdf"
  }
}
EOF

# Invoke locally
sam local invoke -e event.json
```

---

## Getting Help

### AWS Support

**Create Support Case**:
1. AWS Console → Support → Create Case
2. Select service (API Gateway, Lambda, S3)
3. Provide details and logs
4. Attach CloudWatch Logs

### Community Resources

- **Terraform Registry**: Module documentation and examples
- **AWS Forums**: Community Q&A
- **Stack Overflow**: Tag with `aws-lambda`, `terraform`, `amazon-s3`
- **GitHub Issues**: Report module bugs

### Useful Commands

```bash
# Check AWS CLI version
aws --version

# Check Terraform version
terraform version

# Validate Terraform config
terraform validate

# Format Terraform files
terraform fmt -recursive

# Show Terraform plan
terraform plan -out=plan.out

# Show detailed plan
terraform show plan.out
```

---

## Next Steps

- [KB-01-Overview.md](KB-01-Overview.md) - Back to overview
- [KB-02-S3-Module.md](KB-02-S3-Module.md) - S3 configuration details
- [KB-03-Lambda-Module.md](KB-03-Lambda-Module.md) - Lambda configuration details
- [KB-04-API-Gateway-Module.md](KB-04-API-Gateway-Module.md) - API Gateway details
- [KB-05-Limitations.md](KB-05-Limitations.md) - System limitations

# Knowledge Base: S3 Bucket Module

## Module Information

**Module Source**: `terraform-aws-modules/s3-bucket/aws`
**Version**: ~> 4.0
**Registry**: https://registry.terraform.io/modules/terraform-aws-modules/s3-bucket/aws

---

## Purpose

Creates a secure S3 bucket for storing uploaded files with:
- Server-side encryption
- Versioning
- Public access blocking
- CORS configuration for browser uploads

---

## Module Configuration

### Basic Configuration

```hcl
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.0"

  bucket = var.bucket_name
  
  versioning = {
    enabled = true
  }
  
  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  
  cors_rule = [
    {
      allowed_headers = ["*"]
      allowed_methods = ["PUT", "POST"]
      allowed_origins = var.allowed_origins
      expose_headers  = ["ETag"]
      max_age_seconds = 3000
    }
  ]
  
  tags = local.common_tags
}
```

---

## Arguments Explained

### Required Arguments

#### `bucket`
- **Type**: `string`
- **Description**: Name of the S3 bucket (must be globally unique)
- **Constraints**:
  - 3-63 characters
  - Lowercase letters, numbers, hyphens only
  - Must start and end with letter or number
  - Cannot contain consecutive periods
  - Cannot start with `xn--`
- **Example**: `"my-pdf-uploads-bucket-12345"`

### Optional Arguments

#### `versioning`
- **Type**: `object`
- **Description**: Enable versioning to keep multiple versions of objects
- **Default**: `{ enabled = true }`
- **Benefits**:
  - Recover deleted files
  - Restore previous versions
  - Protect against accidental deletion
- **Cost Impact**: Stores all versions (increases storage cost)

#### `server_side_encryption_configuration`
- **Type**: `object`
- **Description**: Encrypt data at rest
- **Algorithm**: `AES256` (AWS-managed keys)
- **Alternative**: `aws:kms` (customer-managed keys)
- **Cost**: Free for AES256, KMS has per-request charges

#### `block_public_acls`
- **Type**: `bool`
- **Description**: Block public ACLs on bucket and objects
- **Default**: `true`
- **Recommendation**: Always `true` for security

#### `block_public_policy`
- **Type**: `bool`
- **Description**: Block public bucket policies
- **Default**: `true`
- **Recommendation**: Always `true` for security

#### `ignore_public_acls`
- **Type**: `bool`
- **Description**: Ignore all public ACLs
- **Default**: `true`
- **Recommendation**: Always `true` for security

#### `restrict_public_buckets`
- **Type**: `bool`
- **Description**: Restrict public bucket policies
- **Default**: `true`
- **Recommendation**: Always `true` for security

#### `cors_rule`
- **Type**: `list(object)`
- **Description**: CORS configuration for browser uploads
- **Required for**: Direct browser-to-S3 uploads

**CORS Rule Structure**:
```hcl
cors_rule = [
  {
    allowed_headers = ["*"]              # Headers browser can send
    allowed_methods = ["PUT", "POST"]    # HTTP methods allowed
    allowed_origins = ["*"]              # Domains allowed (restrict in prod)
    expose_headers  = ["ETag"]           # Headers browser can read
    max_age_seconds = 3000               # Cache preflight for 50 minutes
  }
]
```

#### `tags`
- **Type**: `map(string)`
- **Description**: Resource tags for organization and cost tracking
- **Best Practice**: Include Project, Environment, ManagedBy

---

## Outputs

### `bucket_name`
- **Type**: `string`
- **Description**: Name of the created bucket
- **Use**: Pass to Lambda for S3 operations

### `bucket_arn`
- **Type**: `string`
- **Description**: ARN of the bucket
- **Format**: `arn:aws:s3:::bucket-name`
- **Use**: IAM policy resource specification

### `bucket_domain_name`
- **Type**: `string`
- **Description**: Domain name of the bucket
- **Format**: `bucket-name.s3.amazonaws.com`
- **Use**: Direct S3 access (not recommended for uploads)

### `bucket_region`
- **Type**: `string`
- **Description**: AWS region where bucket is created
- **Use**: Regional configuration

---

## Security Best Practices

### 1. Bucket Naming
❌ **Bad**: `my-bucket` (too generic, likely taken)
❌ **Bad**: `MyBucket` (uppercase not allowed)
✅ **Good**: `mycompany-uploads-prod-us-east-1-12345`

### 2. Public Access
```hcl
# Always use all four settings
block_public_acls       = true
block_public_policy     = true
ignore_public_acls      = true
restrict_public_buckets = true
```

### 3. Encryption
```hcl
# Use AES256 for most cases (free)
sse_algorithm = "AES256"

# Use KMS for compliance requirements
sse_algorithm     = "aws:kms"
kms_master_key_id = aws_kms_key.bucket.arn
```

### 4. Versioning
```hcl
# Enable for production
versioning = {
  enabled = true
}

# Add lifecycle rule to manage old versions
lifecycle_rule = [
  {
    id      = "delete-old-versions"
    enabled = true
    noncurrent_version_expiration = {
      days = 90
    }
  }
]
```

---

## CORS Configuration Deep Dive

### Why CORS is Needed

Without CORS, browsers block direct uploads to S3:
```
Access to XMLHttpRequest at 'https://bucket.s3.amazonaws.com/'
from origin 'https://myapp.com' has been blocked by CORS policy
```

### CORS Headers Explained

#### `allowed_headers`
- **Purpose**: Headers the browser can send in the request
- **`["*"]`**: Allow all headers (simplest)
- **Specific**: `["Content-Type", "x-amz-*"]` (more restrictive)

#### `allowed_methods`
- **Purpose**: HTTP methods allowed
- **`["PUT", "POST"]`**: For file uploads
- **`["GET"]`**: For file downloads (add if needed)

#### `allowed_origins`
- **Development**: `["*"]` (allow all)
- **Production**: `["https://myapp.com", "https://app.mycompany.com"]`
- **Security**: Never use `*` in production

#### `expose_headers`
- **Purpose**: Headers browser JavaScript can read
- **`["ETag"]`**: Needed for upload verification
- **`["x-amz-*"]`**: AWS-specific headers

#### `max_age_seconds`
- **Purpose**: Cache preflight OPTIONS requests
- **`3000`**: 50 minutes (reduces preflight requests)
- **Max**: 86400 (24 hours)

### CORS Troubleshooting

**Issue**: CORS error in browser console

**Check**:
1. Is CORS rule configured?
2. Is origin in `allowed_origins`?
3. Is method in `allowed_methods`?
4. Are headers in `allowed_headers`?

**Test CORS**:
```bash
curl -X OPTIONS \
  -H "Origin: https://myapp.com" \
  -H "Access-Control-Request-Method: POST" \
  https://bucket.s3.amazonaws.com/
```

---

## Cost Optimization

### Storage Costs

| Storage Class | Cost per GB/month | Use Case |
|---------------|-------------------|----------|
| Standard | $0.023 | Frequent access |
| Intelligent-Tiering | $0.023 + $0.0025 | Unknown access patterns |
| Standard-IA | $0.0125 | Infrequent access |
| Glacier | $0.004 | Archive |

### Lifecycle Policy Example

```hcl
lifecycle_rule = [
  {
    id      = "transition-old-files"
    enabled = true
    
    transition = [
      {
        days          = 30
        storage_class = "STANDARD_IA"
      },
      {
        days          = 90
        storage_class = "GLACIER"
      }
    ]
    
    expiration = {
      days = 365
    }
  }
]
```

---

## Limitations

### Bucket Name Limitations
- Must be globally unique across ALL AWS accounts
- Cannot be changed after creation
- Cannot contain uppercase letters
- Cannot contain underscores
- Cannot start with `xn--` or end with `-s3alias`

### CORS Limitations
- Maximum 100 CORS rules per bucket
- Preflight cache max 24 hours
- Cannot use wildcards in `allowed_origins` with credentials

### Versioning Limitations
- Cannot be disabled, only suspended
- Increases storage costs
- Delete markers count as versions

### Regional Limitations
- Bucket is created in one region
- Cross-region replication requires additional setup
- Data transfer costs for cross-region access

---

## Common Patterns

### Pattern 1: Development Bucket
```hcl
bucket = "myapp-dev-uploads"
versioning = { enabled = false }
cors_rule = [{ allowed_origins = ["*"] }]
```

### Pattern 2: Production Bucket
```hcl
bucket = "myapp-prod-uploads-${random_id.bucket.hex}"
versioning = { enabled = true }
cors_rule = [{ allowed_origins = ["https://myapp.com"] }]
lifecycle_rule = [...]
```

### Pattern 3: Compliance Bucket
```hcl
bucket = "myapp-compliance-uploads"
versioning = { enabled = true }
server_side_encryption_configuration = {
  rule = {
    apply_server_side_encryption_by_default = {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.bucket.arn
    }
  }
}
object_lock_enabled = true
```

---

## Monitoring

### CloudWatch Metrics

Enable request metrics:
```hcl
metric_configuration = [
  {
    name = "EntireBucket"
  }
]
```

**Available Metrics**:
- `NumberOfObjects`
- `BucketSizeBytes`
- `AllRequests`
- `GetRequests`
- `PutRequests`
- `4xxErrors`
- `5xxErrors`

### S3 Access Logging

```hcl
logging = {
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access-logs/"
}
```

---

## Next Steps

- [KB-03-Lambda-Module.md](KB-03-Lambda-Module.md) - Lambda configuration
- [KB-04-API-Gateway-Module.md](KB-04-API-Gateway-Module.md) - API Gateway setup

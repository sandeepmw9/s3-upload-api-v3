# S3 Upload API - Using Public Terraform Modules

This implementation uses popular public Terraform modules from the AWS community for production-ready infrastructure.

## Public Modules Used

1. **S3 Bucket**: `terraform-aws-modules/s3-bucket/aws` (~4.0)
   - Battle-tested S3 configuration
   - Built-in security best practices
   - Comprehensive CORS support

2. **Lambda**: `terraform-aws-modules/lambda/aws` (~7.0)
   - Automatic code packaging
   - Built-in IAM role management
   - CloudWatch Logs integration

3. **API Gateway**: `terraform-aws-modules/apigateway-v2/aws` (~5.0)
   - HTTP API (cheaper and simpler than REST API)
   - Native CORS support
   - Automatic Lambda integration

## Architecture

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│  API Gateway (HTTP) │  ← Public Module
│  GET /upload        │
│  POST /upload       │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│  Lambda Function    │  ← Public Module
│  - Generate URL     │
│  - Direct Upload    │
└──────┬──────────────┘
       │
       ▼
┌─────────────────────┐
│    S3 Bucket        │  ← Public Module
│  - Versioning       │
│  - Encryption       │
│  - CORS enabled     │
└─────────────────────┘
```

## Advantages of Public Modules

✅ **Production-Ready**: Tested by thousands of users
✅ **Best Practices**: Security and performance built-in
✅ **Less Code**: ~60% less code than custom modules
✅ **Maintained**: Regular updates and bug fixes
✅ **Documentation**: Extensive examples and docs
✅ **Community Support**: Active GitHub issues/discussions

## Quick Start

```bash
# 1. Copy example variables
cp terraform.tfvars.example terraform.tfvars

# 2. Edit terraform.tfvars (change bucket_name!)
nano terraform.tfvars

# 3. Initialize (downloads public modules)
terraform init

# 4. Review plan
terraform plan

# 5. Deploy
terraform apply
```

## Key Differences from Custom Modules

| Feature | Custom Modules | Public Modules |
|---------|---------------|----------------|
| Code Lines | ~500 | ~200 |
| Maintenance | You | Community |
| Updates | Manual | `terraform init -upgrade` |
| Features | Basic | Advanced |
| Testing | DIY | Pre-tested |
| Documentation | Write yourself | Included |

## Module Versions

Pinned to major versions for stability:
- S3: `~> 4.0` (allows 4.x updates)
- Lambda: `~> 7.0` (allows 7.x updates)
- API Gateway: `~> 5.0` (allows 5.x updates)

## Updating Modules

```bash
# Check for updates
terraform init -upgrade

# Review changes
terraform plan

# Apply updates
terraform apply
```

## Configuration

All configuration is in `terraform.tfvars`:

```hcl
bucket_name = "my-unique-bucket-name"  # MUST BE UNIQUE!
lambda_memory_size = 256
lambda_timeout = 30
allowed_origins = ["*"]  # Restrict in production
```

## Outputs

After deployment:

```bash
# Get API endpoint
terraform output api_endpoint

# Get all outputs
terraform output

# Get usage instructions
terraform output usage_instructions
```

## Cost Estimate

Monthly cost for 10,000 uploads (50MB each):

- API Gateway HTTP: $10.00
- Lambda: $2.00
- S3 Storage: $1.15 (50GB)
- S3 Requests: $0.05
- **Total: ~$13.20/month**

(REST API would be $35/month - HTTP API is 71% cheaper!)

## Security Features

✅ S3 bucket encryption (AES256)
✅ S3 versioning enabled
✅ Public access blocked
✅ IAM least privilege
✅ CloudWatch Logs enabled
✅ CORS properly configured
✅ Presigned URL expiration

## Monitoring

CloudWatch Logs automatically created:
```
/aws/lambda/upload-handler
```

View logs:
```bash
aws logs tail /aws/lambda/upload-handler --follow
```

## Troubleshooting

### Module Download Issues
```bash
terraform init -upgrade
```

### Lambda Code Changes Not Applying
```bash
# Force rebuild
rm -rf lambda/.terraform
terraform apply -replace=module.lambda_function.aws_lambda_function.this[0]
```

### CORS Issues
Check `allowed_origins` in terraform.tfvars

## Clean Up

```bash
# Destroy all resources
terraform destroy

# Empty S3 bucket first if versioning enabled
aws s3 rm s3://YOUR_BUCKET_NAME --recursive
```

## Further Reading

- [S3 Module Docs](https://registry.terraform.io/modules/terraform-aws-modules/s3-bucket/aws)
- [Lambda Module Docs](https://registry.terraform.io/modules/terraform-aws-modules/lambda/aws)
- [API Gateway Module Docs](https://registry.terraform.io/modules/terraform-aws-modules/apigateway-v2/aws)

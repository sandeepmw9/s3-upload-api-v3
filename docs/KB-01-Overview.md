# Knowledge Base: S3 Upload API - Overview

## Document Information
- **Version**: 1.0
- **Last Updated**: 2024
- **Audience**: DevOps Engineers, Cloud Architects, Developers

---

## Table of Contents

1. [KB-01-Overview.md](KB-01-Overview.md) - This document
2. [KB-02-S3-Module.md](KB-02-S3-Module.md) - S3 Bucket Module
3. [KB-03-Lambda-Module.md](KB-03-Lambda-Module.md) - Lambda Module
4. [KB-04-API-Gateway-Module.md](KB-04-API-Gateway-Module.md) - API Gateway Module
5. [KB-05-Limitations.md](KB-05-Limitations.md) - Limitations & Constraints
6. [KB-06-Troubleshooting.md](KB-06-Troubleshooting.md) - Common Issues

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                         Browser/Client                        │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ HTTPS Request
                         ▼
┌──────────────────────────────────────────────────────────────┐
│              API Gateway (HTTP API v2)                        │
│  ┌────────────────────┐  ┌────────────────────┐             │
│  │  GET /upload       │  │  POST /upload      │             │
│  │  (Presigned URL)   │  │  (Direct Upload)   │             │
│  └────────────────────┘  └────────────────────┘             │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Lambda Proxy Integration
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                    Lambda Function                            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Handler: lambda_function.lambda_handler             │   │
│  │  Runtime: Python 3.11                                │   │
│  │  Memory: 256 MB                                      │   │
│  │  Timeout: 30 seconds                                 │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  Functions:                                                   │
│  • generate_presigned_url() - For large files               │
│  • handle_direct_upload() - For small files                 │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ S3 API Calls
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                      S3 Bucket                                │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Security:                                           │   │
│  │  • Versioning: Enabled                               │   │
│  │  • Encryption: AES256                                │   │
│  │  • Public Access: Blocked                            │   │
│  │  • CORS: Enabled for browser uploads                 │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  Structure:                                                   │
│  └── uploads/                                                │
│      ├── 20240220_123456_abc12345.pdf                       │
│      ├── 20240220_123457_def67890.pdf                       │
│      └── ...                                                 │
└──────────────────────────────────────────────────────────────┘
```

---

## Component Summary

### 1. S3 Bucket Module
**Purpose**: Secure file storage with encryption and versioning

**Module**: `terraform-aws-modules/s3-bucket/aws`
**Version**: ~> 4.0

**Key Features**:
- Server-side encryption (AES256)
- Versioning enabled
- Public access blocked
- CORS configured for browser uploads

---

### 2. Lambda Function Module
**Purpose**: Process uploads and generate presigned URLs

**Module**: `terraform-aws-modules/lambda/aws`
**Version**: ~> 7.0

**Key Features**:
- Automatic code packaging
- IAM role management
- CloudWatch Logs integration
- Environment variable configuration

---

### 3. API Gateway Module
**Purpose**: HTTP API endpoint for file uploads

**Module**: `terraform-aws-modules/apigateway-v2/aws`
**Version**: ~> 5.0

**Key Features**:
- HTTP API (cheaper than REST API)
- Native CORS support
- Lambda proxy integration
- Throttling controls

---

## Upload Flow Diagrams

### Flow 1: Large File Upload (Presigned URL)

```
1. Client Request
   GET /upload?filename=large.pdf&contentType=application/pdf
   │
   ▼
2. API Gateway → Lambda
   │
   ▼
3. Lambda generates presigned URL
   • Creates unique S3 key
   • Sets expiration (1 hour)
   • Adds security conditions
   │
   ▼
4. Returns presigned URL to client
   {
     "uploadUrl": "https://bucket.s3.amazonaws.com/",
     "fields": {...},
     "key": "uploads/20240220_123456_abc.pdf"
   }
   │
   ▼
5. Client uploads DIRECTLY to S3
   POST to uploadUrl with fields + file
   │
   ▼
6. S3 stores file
   ✓ Encrypted
   ✓ Versioned
```

### Flow 2: Small File Upload (Direct)

```
1. Client Request
   POST /upload
   Body: base64-encoded file
   │
   ▼
2. API Gateway → Lambda
   │
   ▼
3. Lambda processes file
   • Decodes base64
   • Validates PDF format
   • Checks file size
   │
   ▼
4. Lambda uploads to S3
   • Generates unique filename
   • Sets encryption
   │
   ▼
5. Returns success response
   {
     "message": "File uploaded successfully",
     "filename": "uploads/20240220_123456_abc.pdf",
     "size": 524288
   }
```

---

## File Size Limits

| Upload Method | Max Size | Reason | Use Case |
|---------------|----------|--------|----------|
| **Direct POST** | 6 MB | Lambda payload limit | Small files, quick uploads |
| **Presigned URL** | 5 GB | S3 single PUT limit | Large files, browser uploads |
| **Multipart** | 5 TB | S3 multipart limit | Not implemented (future) |

---

## Cost Breakdown

### Monthly Cost Estimate (10,000 uploads, 50MB each)

| Service | Usage | Cost |
|---------|-------|------|
| **API Gateway HTTP** | 10,000 requests | $0.01 |
| **Lambda** | 10,000 invocations × 30s | $2.00 |
| **S3 Storage** | 500 GB stored | $11.50 |
| **S3 PUT Requests** | 10,000 requests | $0.05 |
| **Data Transfer** | Minimal (presigned) | $0.00 |
| **CloudWatch Logs** | 1 GB logs | $0.50 |
| **Total** | | **~$14.06/month** |

### Cost Comparison

| API Type | Cost per Million Requests |
|----------|---------------------------|
| REST API | $3.50 |
| HTTP API | $1.00 |
| **Savings** | **71% cheaper** |

---

## Security Features

### 1. S3 Bucket Security
✅ Server-side encryption (AES256)
✅ Versioning enabled (recover deleted files)
✅ Public access blocked (all 4 settings)
✅ CORS restricted to allowed origins

### 2. IAM Security
✅ Least privilege principle
✅ Lambda can only write to specific bucket
✅ No read permissions (write-only)
✅ CloudWatch Logs access only

### 3. API Security
✅ HTTPS only
✅ Throttling enabled (prevent abuse)
✅ CORS configured (prevent unauthorized domains)
✅ Presigned URLs expire (time-limited access)

### 4. Lambda Security
✅ No hardcoded credentials
✅ Environment variables for config
✅ Error logging (no sensitive data)
✅ Input validation (PDF format check)

---

## Performance Characteristics

### Latency

| Operation | Typical Latency |
|-----------|----------------|
| Generate presigned URL | 50-100ms |
| Direct upload (1MB) | 200-500ms |
| Direct upload (6MB) | 1-2 seconds |
| Presigned upload (100MB) | 5-10 seconds |

### Throughput

| Metric | Limit | Notes |
|--------|-------|-------|
| API Gateway | 10,000 RPS | Default account limit |
| Lambda Concurrency | 1,000 | Default account limit |
| S3 PUT | 3,500 RPS | Per prefix |

---

## Monitoring & Observability

### CloudWatch Metrics

**Lambda Metrics**:
- Invocations
- Duration
- Errors
- Throttles
- Concurrent Executions

**API Gateway Metrics**:
- Count (requests)
- 4XXError
- 5XXError
- Latency
- IntegrationLatency

**S3 Metrics**:
- NumberOfObjects
- BucketSizeBytes
- AllRequests
- 4xxErrors
- 5xxErrors

### CloudWatch Logs

**Log Group**: `/aws/lambda/upload-handler`

**Log Format**:
```
SUCCESS: Generated presigned URL for uploads/20240220_123456_abc.pdf
ERROR: Invalid PDF format - magic bytes check failed
ERROR: File size 7340032 exceeds limit of 6291456 bytes
```

---

## Next Steps

Continue to specific module documentation:
- [KB-02-S3-Module.md](KB-02-S3-Module.md) - Detailed S3 configuration
- [KB-03-Lambda-Module.md](KB-03-Lambda-Module.md) - Lambda implementation
- [KB-04-API-Gateway-Module.md](KB-04-API-Gateway-Module.md) - API Gateway setup
- [KB-05-Limitations.md](KB-05-Limitations.md) - Known limitations

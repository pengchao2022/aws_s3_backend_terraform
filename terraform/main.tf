provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# ============================================
# S3 Bucket - 通用幂等处理
# ============================================

# 尝试获取已存在的 S3 桶
data "aws_s3_bucket" "existing" {
  bucket = var.bucket_name
}

locals {
  # 安全地尝试获取现有桶的信息
  existing_bucket = try(data.aws_s3_bucket.existing, null)
  bucket_exists   = local.existing_bucket != null && local.existing_bucket.id != null
}

# 创建 S3 桶（仅在不存在时创建）
resource "aws_s3_bucket" "terraform_state" {
  count = local.bucket_exists ? 0 : 1
  
  bucket = var.bucket_name
  
  tags = {
    Name        = var.bucket_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "Terraform State Storage"
  }
}

# 版本控制
resource "aws_s3_bucket_versioning" "terraform_state" {
  count = local.bucket_exists ? 0 : 1
  
  bucket = local.bucket_exists ? local.existing_bucket.id : aws_s3_bucket.terraform_state[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# 加密配置
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count = local.bucket_exists ? 0 : 1
  
  bucket = local.bucket_exists ? local.existing_bucket.id : aws_s3_bucket.terraform_state[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 阻止公共访问
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  count = local.bucket_exists ? 0 : 1
  
  bucket = local.bucket_exists ? local.existing_bucket.id : aws_s3_bucket.terraform_state[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================
# DynamoDB Table - 通用幂等处理
# ============================================

# 尝试获取已存在的 DynamoDB 表
data "aws_dynamodb_table" "existing" {
  name = var.dynamodb_table_name
}

locals {
  existing_table = try(data.aws_dynamodb_table.existing, null)
  table_exists   = local.existing_table != null && local.existing_table.id != null
}

# 创建 DynamoDB 表（仅在不存在时创建）
resource "aws_dynamodb_table" "terraform_lock" {
  count = local.table_exists ? 0 : 1
  
  name           = var.dynamodb_table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = var.dynamodb_table_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "Terraform State Lock"
  }
}

# ============================================
# IAM Policy - 通用幂等处理
# ============================================

# 尝试获取已存在的 IAM Policy
data "aws_iam_policy" "existing_policy" {
  name = "TerraformStateAccess-${var.environment}"
}

locals {
  existing_policy = try(data.aws_iam_policy.existing_policy, null)
  policy_exists   = local.existing_policy != null && local.existing_policy.arn != null
}

# ============================================
# 最终的资源引用（统一在这一块定义）
# ============================================

locals {
  # S3 最终引用
  final_bucket_id  = local.bucket_exists ? local.existing_bucket.id : aws_s3_bucket.terraform_state[0].id
  final_bucket_arn = local.bucket_exists ? local.existing_bucket.arn : aws_s3_bucket.terraform_state[0].arn
  
  # DynamoDB 最终引用
  final_table_arn = local.table_exists ? local.existing_table.arn : aws_dynamodb_table.terraform_lock[0].arn
  
  # IAM Policy 最终引用
  final_policy_arn = local.policy_exists ? local.existing_policy.arn : aws_iam_policy.terraform_state_access[0].arn
}

# 创建 IAM Policy（仅在不存在时创建）
resource "aws_iam_policy" "terraform_state_access" {
  count = local.policy_exists ? 0 : 1
  
  name        = "TerraformStateAccess-${var.environment}"
  description = "Policy to allow access to Terraform state S3 bucket and DynamoDB lock table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          local.final_bucket_arn,
          "${local.final_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = local.final_table_arn
      }
    ]
  })
}



provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# try to get the exist s3 bucket info
data "aws_s3_bucket" "existing" {
  bucket = var.bucket_name
}

locals {
  # try to get the s3 info if it exists
  existing_bucket = try(data.aws_s3_bucket.existing, null)
  bucket_exists   = local.existing_bucket != null && local.existing_bucket.id != null
}

# create s3 only it's not exist 
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

# s3 version control
resource "aws_s3_bucket_versioning" "terraform_state" {
  count = local.bucket_exists ? 0 : 1
  
  bucket = local.bucket_exists ? local.existing_bucket.id : aws_s3_bucket.terraform_state[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# encrypt configration
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count = local.bucket_exists ? 0 : 1
  
  bucket = local.bucket_exists ? local.existing_bucket.id : aws_s3_bucket.terraform_state[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# block public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  count = local.bucket_exists ? 0 : 1
  
  bucket = local.bucket_exists ? local.existing_bucket.id : aws_s3_bucket.terraform_state[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# DynamoDB Table 


# get the dynamodb table if it exists
data "aws_dynamodb_table" "existing" {
  name = var.dynamodb_table_name
}

locals {
  existing_table = try(data.aws_dynamodb_table.existing, null)
  table_exists   = local.existing_table != null && local.existing_table.id != null
}

# create dynamodb table only if it not exists
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


# IAM Policy 
# try to get the exist IAM policy
data "aws_iam_policy" "existing_policy" {
  name = "TerraformStateAccess-${var.environment}"
}

locals {
  existing_policy = try(data.aws_iam_policy.existing_policy, null)
  policy_exists   = local.existing_policy != null && local.existing_policy.arn != null
}


# Final resource references (all defined in this section)
locals {
  # s3 final refrence 
  final_bucket_id  = local.bucket_exists ? local.existing_bucket.id : aws_s3_bucket.terraform_state[0].id
  final_bucket_arn = local.bucket_exists ? local.existing_bucket.arn : aws_s3_bucket.terraform_state[0].arn
  
  # DynamoDB final reference
  final_table_arn = local.table_exists ? local.existing_table.arn : aws_dynamodb_table.terraform_lock[0].arn
  
  # IAM Policy final reference
  final_policy_arn = local.policy_exists ? local.existing_policy.arn : aws_iam_policy.terraform_state_access[0].arn
}

# create IAM policy only it not exists
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



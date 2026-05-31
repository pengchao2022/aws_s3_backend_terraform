output "s3_bucket_name" {
  value = local.final_bucket_id
}

output "s3_bucket_arn" {
  value = local.final_bucket_arn
}

output "dynamodb_table_name" {
  value = var.dynamodb_table_name
}

output "dynamodb_table_arn" {
  value = local.final_table_arn
}

output "state_access_policy_arn" {
  value = aws_iam_policy.terraform_state_access.arn
}

output "resources_status" {
  value = {
    bucket_created   = !local.bucket_exists
    table_created    = !local.table_exists
    bucket_name      = local.final_bucket_id
    dynamodb_table   = var.dynamodb_table_name
  }
}
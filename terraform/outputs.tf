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
  value = local.final_policy_arn
}

output "iam_policy_arn" {
  value = local.final_policy_arn
}

output "resources_status" {
  value = {
    bucket_created   = !local.bucket_exists
    table_created    = !local.table_exists
    policy_created   = !local.policy_exists
    bucket_name      = local.final_bucket_id
    dynamodb_table   = var.dynamodb_table_name
    policy_arn       = local.final_policy_arn
  }
}
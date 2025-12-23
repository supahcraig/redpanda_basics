output "aurora_cluster_endpoint" {
  value = aws_rds_cluster.aurora.endpoint
}

output "aurora_instance_endpoint" {
  value = aws_rds_cluster_instance.aurora.endpoint
}

output "aurora_cluster_resource_id" {
  value = aws_rds_cluster.aurora.cluster_resource_id
}

output "rpconnect_app_role_arn" {
  value = aws_iam_role.rpconnect_app_role.arn
}

output "cross_account_db_access_role_arn" {
  value = aws_iam_role.cross_account_db_access_role.arn
}

output "rpconnect_client_public_ip" {
  value = aws_instance.rpconnect_client.public_ip
}

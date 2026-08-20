output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.this.name
}

output "alb_dns_name" {
  description = "Public HTTP URL to open in a browser for the demo."
  value       = "http://${aws_lb.this.dns_name}"
}

output "s3_bucket" {
  description = "S3 bucket the ECS task reads its content from (the ECS -> S3 integration point)."
  value       = aws_s3_bucket.content.id
}

output "task_role_arn" {
  description = "IAM role assumed by the running task (scoped to S3 read of index.html only)."
  value       = aws_iam_role.task.arn
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

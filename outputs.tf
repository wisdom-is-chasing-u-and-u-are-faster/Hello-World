output "function_name" {
  description = "Deployed Lambda function name."
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "Lambda function ARN."
  value       = aws_lambda_function.this.arn
}

output "function_url" {
  description = "Public HTTP URL to open in a browser for the demo."
  value       = aws_lambda_function_url.this.function_url
}

output "log_group" {
  description = "CloudWatch Log Group where logs land."
  value       = aws_cloudwatch_log_group.lambda.name
}

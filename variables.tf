variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1"
}

variable "function_name" {
  description = "Name of the Lambda function."
  type        = string
  default     = "hello-lambda"
}

variable "lambda_runtime" {
  description = "Lambda runtime."
  type        = string
  default     = "python3.12"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days (keeps cost low)."
  type        = number
  default     = 14
}

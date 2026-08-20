variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1" # Mumbai (closest to Bangalore) - matches the other demos in this repo
}

variable "project_name" {
  description = "Name prefix for all resources (cluster, service, ALB, bucket, IAM roles, etc.)."
  type        = string
  default     = "hello-ecs"
}

variable "vpc_cidr" {
  description = "CIDR block for the demo VPC. Kept distinct from the Lambda (no VPC) and EKS (10.0.0.0/16) demo VPCs so all three can coexist in the same account without conflict."
  type        = string
  default     = "10.1.0.0/16"
}

variable "container_image" {
  description = "Public web server image for the 'web' container. No custom image build/push is required for this demo."
  type        = string
  default     = "public.ecr.aws/nginx/nginx:1.27-alpine"
}

variable "fetch_content_image" {
  description = "Public AWS CLI image used by the init/sidecar container that pulls the demo page from S3 before nginx starts. No custom image build required."
  type        = string
  default     = "public.ecr.aws/aws-cli/aws-cli:latest"
}

variable "container_port" {
  description = "Port the 'web' container listens on."
  type        = number
  default     = 80
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU). Kept small to minimize demo cost."
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Fargate task memory in MB."
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Number of ECS tasks to run."
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the ECS task containers (keeps cost low)."
  type        = number
  default     = 7
}

variable "aws_region" {
  description = "AWS region to deploy the EKS cluster into."
  type        = string
  default     = "ap-south-1" # Mumbai (closest to Bangalore)
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "hello-eks"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes control plane version."
  type        = string
  default     = "1.30"
}

variable "instance_type" {
  description = "EC2 instance type for the managed node group (kept small for demo cost)."
  type        = string
  default     = "t3.small"
}

variable "desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 3
}

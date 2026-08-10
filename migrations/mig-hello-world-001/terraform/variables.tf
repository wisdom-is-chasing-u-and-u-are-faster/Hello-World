# variables.tf
variable "project_id" {
  type        = string
  description = "Target GCP project id."
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "Cloud Run region."
}

variable "image" {
  type        = string
  description = "Container image URL (Artifact Registry) for the Cloud Run service."
}

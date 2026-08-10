# main.tf — GCP Cloud Run service (ported from AWS Lambda "hosted-in-aws-page").
terraform {
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Dedicated least-privilege service account for the Cloud Run service.
resource "google_service_account" "run_sa" {
  account_id   = "hosted-in-gcp-sa"
  display_name = "Service account for hosted-in-gcp Cloud Run service"
}

# The Cloud Run service (image built from ./.. via Cloud Build / gcloud run deploy).
resource "google_cloud_run_v2_service" "svc" {
  name     = "hosted-in-gcp"
  location = var.region

  template {
    service_account = google_service_account.run_sa.email
    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
    containers {
      image = var.image
      resources {
        limits = { cpu = "1", memory = "128Mi" }
      }
      ports { container_port = 8080 }
    }
  }
}

# outputs.tf
output "service_url" {
  value       = google_cloud_run_v2_service.svc.uri
  description = "Public HTTPS URL of the migrated Cloud Run service."
}

output "service_account_email" {
  value       = google_service_account.run_sa.email
  description = "Runtime service account for the Cloud Run service."
}

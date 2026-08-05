output "raw_landing_bucket_name" {
  description = "Name of the D0 raw landing GCS bucket."
  value       = google_storage_bucket.raw_landing.name
}

output "staged_enforced_dataset_id" {
  description = "BigQuery dataset ID for D1 staged/enforced data."
  value       = google_bigquery_dataset.staged_enforced.dataset_id
}

output "student_onboarding_table_id" {
  description = "Fully-qualified table ID for the validated student onboarding table."
  value       = "${var.project_id}.${google_bigquery_dataset.staged_enforced.dataset_id}.${google_bigquery_table.student_onboarding.table_id}"
}

output "row_access_policy_id" {
  description = "ID of the row-level security policy enforcing tenant isolation."
  value       = google_bigquery_row_access_policy.tenant_isolation.policy_id
}

variable "project_id" {
  description = "The GCP project ID that owns the staging resources."
  type        = string
}

variable "region" {
  description = "The GCP region for regional resources such as the GCS bucket."
  type        = string
  default     = "asia-south1"
}

variable "bq_location" {
  description = "The location for the BigQuery dataset. Multi-region values (e.g. asia-south1) are also valid."
  type        = string
  default     = "asia-south1"
}

variable "environment" {
  description = "Deployment environment tag applied to all resources for cost tracking and access scoping."
  type        = string
  default     = "staging"
}

variable "data_engineer_group" {
  description = "Google Group email that is granted least-privilege access to the staged/enforced BigQuery dataset. Using a group instead of individual users keeps IAM auditable and avoids per-person role sprawl."
  type        = string
  default     = "data-engineers-staging@habotconnect.com"
}

variable "pipeline_service_account" {
  description = "Service account email used by the automated CI/CD pipeline to write into the raw landing bucket. Scoped to object-create only, never full bucket admin."
  type        = string
  default     = "pipeline-writer@habotconnect-staging.iam.gserviceaccount.com"
}

variable "bucket_force_destroy" {
  description = "Whether Terraform is allowed to delete the raw landing bucket even if it still contains objects. Kept false by default to prevent accidental data loss."
  type        = bool
  default     = false
}

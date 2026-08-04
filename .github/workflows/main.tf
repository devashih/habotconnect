############################################
# D0 — RAW LANDING (Google Cloud Storage)
############################################
# Purpose: durable, immutable landing zone for raw incoming payloads
# (e.g. student onboarding JSON) before any schema validation runs.

resource "google_storage_bucket" "raw_landing" {
  name     = "${var.project_id}-d0-raw-landing"
  location = var.region
  project  = var.project_id

  # Uniform bucket-level access means every permission is granted through
  # IAM only — no legacy per-object ACLs that are easy to misconfigure.
  uniform_bucket_level_access = true

  # No object can ever be made public, even by accident or a future
  # misconfigured IAM binding. This is enforced at the bucket level.
  public_access_prevention = "enforced"

  # Object versioning protects against accidental overwrite/delete of
  # raw source data — critical since D0 is the only copy of the
  # untouched payload before transformation.
  versioning {
    enabled = true
  }

  # Raw landing data is transitional. After 30 days it moves to cheaper
  # storage; after 90 days old versions are purged to control cost.
  lifecycle_rule {
    condition {
      age                   = 30
      matches_storage_class = ["STANDARD"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age        = 90
      with_state = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  # All data at rest is encrypted with Google-managed keys by default.
  # No CMEK block is declared here since customer-managed encryption is
  # not required at this stage — Google-managed encryption applies implicitly.

  labels = {
    environment = var.environment
    data_zone   = "d0-raw-landing"
    managed_by  = "terraform"
  }

  force_destroy = var.bucket_force_destroy
}

# --- Least-privilege IAM: pipeline can only CREATE objects, never list,
# read, or delete anything else in the bucket. This limits blast radius
# if the pipeline's credentials are ever compromised. ---
resource "google_storage_bucket_iam_member" "pipeline_object_creator" {
  bucket = google_storage_bucket.raw_landing.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${var.pipeline_service_account}"

  condition {
    title       = "restrict-to-onboarding-prefix"
    description = "Pipeline may only write objects under the student-onboarding/ prefix, nothing else in the bucket."
    expression  = "resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.raw_landing.name}/objects/student-onboarding/\")"
  }
}


############################################
# D1 — STAGED / ENFORCED (BigQuery)
############################################
# Purpose: validated, schema-enforced data ready for downstream
# analytics consumption. Only reachable after DCYN validation passes.

resource "google_bigquery_dataset" "staged_enforced" {
  dataset_id                 = "D1_staged_enforced"
  project                    = var.project_id
  location                   = var.bq_location
  description                = "Schema-enforced staging dataset for validated student onboarding records. Row-level security restricts visibility by tenant."
  delete_contents_on_destroy = false

  labels = {
    environment = var.environment
    data_zone   = "d1-staged-enforced"
  }

  # Explicit, least-privilege access list — no broad "allUsers" or
  # project-level primitive roles (Editor/Owner) anywhere near this dataset.
  access {
    role           = "READER"
    group_by_email = var.data_engineer_group
  }

  access {
    role          = "WRITER"
    user_by_email = var.pipeline_service_account
  }

  access {
    role          = "OWNER"
    special_group = "projectOwners"
  }
}

resource "google_bigquery_table" "student_onboarding" {
  dataset_id          = google_bigquery_dataset.staged_enforced.dataset_id
  table_id            = "student_onboarding"
  project             = var.project_id
  deletion_protection = true

  schema = jsonencode([
    { name = "record_id", type = "STRING", mode = "REQUIRED", description = "Unique onboarding submission identifier." },
    { name = "tenant_id", type = "STRING", mode = "REQUIRED", description = "Owning tenant/LSA-provider organization; drives row-level security." },
    { name = "student_full_name", type = "STRING", mode = "REQUIRED", description = "Full legal name of the student, no abbreviations." },
    { name = "guardian_email", type = "STRING", mode = "REQUIRED", description = "Verified guardian contact email." },
    { name = "learning_support_need", type = "STRING", mode = "REQUIRED", description = "Enumerated learning-support category, validated against a fixed choice list." },
    { name = "consent_confirmed", type = "BOOLEAN", mode = "REQUIRED", description = "Binary Yes/No consent flag — must be TRUE for the record to reach this table at all." },
    { name = "ingested_at", type = "TIMESTAMP", mode = "REQUIRED", description = "Pipeline ingestion timestamp, used for freshness and audit." }
  ])

  labels = {
    environment = var.environment
  }
}

# --- Row-Level Security: each reader only ever sees rows belonging to
# their own tenant. This enforces multi-tenant data isolation directly
# in BigQuery, rather than trusting every downstream query to filter
# correctly (removing reliance on "hope" or human diligence). ---
resource "google_bigquery_row_access_policy" "tenant_isolation" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.staged_enforced.dataset_id
  table_id   = google_bigquery_table.student_onboarding.table_id
  policy_id  = "tenant_isolation_policy"

  filter_predicate = "tenant_id IN (SELECT tenant_id FROM `${var.project_id}.D1_staged_enforced.tenant_access_map` WHERE user_email = SESSION_USER())"

  grantees = [
    "group:${var.data_engineer_group}",
  ]
}

# Small lookup table the RLS policy above depends on: maps a reader's
# email to the tenant(s) they are authorized to see. Kept in the same
# dataset so access logic lives alongside the data it governs.
resource "google_bigquery_table" "tenant_access_map" {
  dataset_id          = google_bigquery_dataset.staged_enforced.dataset_id
  table_id            = "tenant_access_map"
  project             = var.project_id
  deletion_protection = true

  schema = jsonencode([
    { name = "user_email", type = "STRING", mode = "REQUIRED", description = "Reader's authenticated email, matched against SESSION_USER()." },
    { name = "tenant_id", type = "STRING", mode = "REQUIRED", description = "Tenant this user is authorized to view." }
  ])
}

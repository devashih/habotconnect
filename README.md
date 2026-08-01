# HabotConnect Hiring Project — Deployment & Automation Blueprint

**Position:** Junior Cloud & DevOps Engineer (GCP / Django / React)
**Submitted by:** Devashish Sharma
**Contact:** devashishsharma2107@gmail.com | +91-9509197851

---

## What This Repository Contains

This is my submission for HabotConnect's Hiring Project Form, addressing the three
required tasks: secure staging provisioning (Terraform), a Poka-Yoke CI/CD build gate
(GitHub Actions), and schema validation with DCYN logic (Django REST Framework).

```
.
├── terraform/
│   ├── main.tf          — D0 raw landing GCS bucket + D1 staged/enforced BigQuery
│   │                       dataset, IAM conditions, and row-level security policy
│   ├── variables.tf     — Input variables for project, region, and access scoping
│   ├── outputs.tf       — Terraform outputs for verification
│   └── versions.tf      — Provider version pinning
│
├── .github/workflows/
│   └── build-gate.yml   — Poka-Yoke fail-closed CI/CD gate: lint, secret-scan,
│                           and deploy (deploy only runs if both prior jobs pass)
│
├── schema/
│   ├── serializers.py       — DRF serializer for the student onboarding payload,
│   │                           with exact field-level validation and a DCYN
│   │                           (Deconstructed Clean Yes/No) consent gate
│   └── dcyn-mapping.xlsx    — Field-by-field DCYN decision logic, wrap-text enabled
│
├── backend/
│   └── health.py         — Minimal placeholder file used to demonstrate the
│                            lint/format gate in the CI/CD pipeline
│
├── frontend/
│   ├── package.json
│   ├── package-lock.json
│   ├── eslint.config.js
│   └── src/health.js     — Minimal placeholder used to demonstrate the eslint gate
│
└── README.md              — This file
```

---

## Task 1 — Terraform (Secure Staging Provisioning)

`terraform/main.tf` provisions:
- **D0 Raw Landing** — a GCS bucket with uniform bucket-level access, enforced public
  access prevention, and object versioning.
- **D1 Staged/Enforced** — a BigQuery dataset and table with row-level security,
  restricting each reader to only the rows belonging to their own tenant.
- Least-privilege IAM throughout — no primitive `Editor`/`Owner` roles anywhere near
  the data; access is scoped via explicit conditions and group-based grants.

Validated locally with:
```bash
terraform init
terraform validate
```
Result: `Success! The configuration is valid.`

`terraform plan` / `apply` were intentionally not run against a live billed GCP
project — this submission is scoped to validation-level evidence rather than a live
deployment, a deliberate choice I'm happy to discuss further at interview.

---

## Task 2 — Poka-Yoke CI/CD Build Gate

`.github/workflows/build-gate.yml` defines three jobs:
- **lint** — `black`, `flake8`, and `eslint`, no warnings-only mode.
- **secret-scan** — `gitleaks`, scanning full push history for hardcoded credentials.
- **deploy** — gated with `needs: [lint, secret-scan]`. GitHub Actions structurally
  cannot start this job unless both prior jobs succeed — there is no manual override
  or skip-check path.

This was demonstrated by committing a fake hardcoded secret to `backend/health.py`,
which correctly caused a job to fail and `deploy` to be skipped. See the full run
history under the repository's **Actions** tab.

---

## Task 3 — Schema Mapping & DCYN Validation

`schema/serializers.py` deconstructs the student onboarding JSON payload into six
fields, each with an exact, exhaustive validation rule (UUID format, regex-locked
tenant ID, closed enum for support category, and a hard boolean gate on guardian
consent). `schema/dcyn-mapping.xlsx` documents the Yes/No decision logic for each
field in spreadsheet form, with wrap text enabled throughout.

The serializer was tested against real payloads using an installed DRF environment —
not just written and assumed to work.

---

## Notes

Full walkthrough and screenshots (Terraform validation, CI/CD gate passing and
fail-closed runs) are included in the accompanying project PDF submitted alongside
this repository link.

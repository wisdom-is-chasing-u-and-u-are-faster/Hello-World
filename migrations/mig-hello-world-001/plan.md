# Migration Plan — AWS Lambda -> GCP Cloud Run

**Service:** hosted-in-gcp
**Source:** AWS Lambda `hello-lambda` (stateless HTML page, python3.12, Function URL)
**Target:** GCP Cloud Run (persistent-genai / us-central1)

## What changes
- Lambda `handler(event, context)` -> Flask HTTP server (`main.py`).
- HTML message flips: "This function is hosted in AWS" -> "This function is hosted in GCP".
- No dependencies, no VPC, no secrets — clean lift.

## Artifacts in this PR
- `main.py`            — ported Flask app
- `requirements.txt`   — Flask + gunicorn
- `Dockerfile`         — Cloud Run container
- `terraform/main.tf`  — Cloud Run service + service account (IaC)
- `terraform/variables.tf`
- `terraform/outputs.tf`
- `plan.md`            — this document

## Deploy
`gcloud run deploy hosted-in-gcp --source .` (used by the agent), or apply the Terraform
with a built image URL.

## Cutover & rollback
Weighted 5% -> 25% -> 50% -> 100% with rollback triggers. Keep the AWS Lambda disabled (not
deleted) through the soak period; decommission is manual only.

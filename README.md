# hello-lambda — AWS Lambda (source workload for AWS→GCP migration)

A minimal AWS Lambda that serves a single HTML page:
**"This function is hosted in AWS"** — reachable via a public **Function URL**
you can open in a browser and show to a customer.

This repository is the **source-of-truth IaC** for the workload. The migration
agent reads this Terraform to build its migration plan (Lambda → Cloud Run) and
to drive deployment.

---

## Workload summary (for the migration agent)

| Attribute | Value |
|---|---|
| Workload type | AWS Lambda (single function) |
| Function name | `hello-lambda` |
| Runtime | `python3.12` |
| Handler | `handler.handler` |
| Memory | 128 MB |
| Timeout | 10 s |
| Trigger | Lambda **Function URL** (public HTTP, `authorization_type = NONE`) |
| Response | Static HTML page (`text/html`), no dependencies |
| State | Stateless — no database, no storage, no secrets |
| Region | `ap-south-1` (default; override via `aws_region`) |
| Logs | CloudWatch Log Group `/aws/lambda/hello-lambda`, 14-day retention |
| IAM | Execution role + `AWSLambdaBasicExecutionRole` (logs only) |

**GCP migration target:** Cloud Run (service or functions Gen 2). The Function
URL maps to a Cloud Run HTTPS URL; the handler returns the same HTML with the
text changed to "This function is hosted in GCP" at cutover. Because the
workload is stateless with a single HTTP trigger and no dependencies, it is a
clean, low-risk lift.

---

## Repository layout

```
.
├── versions.tf      # Terraform + AWS/archive providers
├── variables.tf     # region, function name, runtime, log retention
├── main.tf          # IAM role, log group, Lambda, Function URL
├── outputs.tf       # prints the browsable function_url
├── src/
│   └── handler.py   # returns the "hosted in AWS" HTML page
├── .gitignore       # excludes state, .terraform, zips
└── README.md
```

---

## Deploy (manual)

Prerequisites: AWS CLI configured (`aws configure`) and Terraform ≥ 1.6.

```bash
terraform init
terraform plan
terraform apply        # type: yes
terraform output -raw function_url   # open this URL in a browser
```

Test:
```bash
curl "$(terraform output -raw function_url)"
```

Tear down:
```bash
terraform destroy
```

---

## Notes

- State is **local** by default. `terraform.tfstate` is git-ignored — never commit it.
- Function URL is `authorization_type = NONE` (public) for easy demo. Set to
  `AWS_IAM` to lock it down.
- Kept intentionally tiny and dependency-free so the AWS→GCP migration is a
  clean before/after demo.

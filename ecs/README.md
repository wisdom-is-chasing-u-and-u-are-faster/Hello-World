# hello-ecs — Amazon ECS Fargate workload (source for AWS→GCP migration)

A minimal **Amazon ECS on Fargate** application that serves a single page —
**"This is Deployed in ECS"** — reachable via a public **Application Load
Balancer** URL. This is the **ECS → GCP** counterpart to the `Lambda → Cloud
Run` and `EKS → GKE` workloads already in this repo (root and `eks/`
respectively). It is a **separate, self-contained application and
infrastructure stack** — nothing in `Lambda` (`main.tf`, `src/`) or `EKS`
(`eks/`) is touched, read, or referenced by this stack.

Unlike the EKS/Lambda demos, this one also has a **real dependency on
another AWS service (S3)**, on purpose: it gives an ECS→GCP migration agent
a genuine "workload talks to S3" corner case to detect and plan for
(ECS + ALB + S3 → Cloud Run/GKE + Cloud Load Balancing + GCS).

---

## Why ECS is a good third demo case

| Attribute | Lambda (root) | EKS (`eks/`) | **ECS (`ecs/`, this one)** |
|---|---|---|---|
| Compute model | Function-per-invocation | Full Kubernetes cluster | Managed container orchestration, no cluster nodes to manage (Fargate) |
| Closest GCP target | Cloud Run (functions) | GKE | **Cloud Run (service)** or GKE, depending on workload shape |
| Networking exposure | Function URL | `Service type=LoadBalancer` (NLB) | **Application Load Balancer** (Layer 7 — closest analog to GCP's external HTTPS Load Balancer) |
| External dependency | None | None | **S3** (read-only) — a common real-world coupling the agent must detect |
| Build step | Zip only, no Docker | Uses stock `nginx` image | **No custom image build** — stock `nginx` + stock `aws-cli` images with an ECS-native sidecar pattern |

---

## Repository layout

```
ecs/
├── terraform/
│   ├── versions.tf     # Terraform + AWS provider
│   ├── variables.tf    # region, names, sizing (all have sane defaults)
│   ├── vpc.tf          # VPC, 2 public subnets, NO NAT Gateway (cost control)
│   ├── s3.tf           # S3 bucket + the demo HTML object
│   ├── iam.tf          # execution role (pull/log) + task role (S3 read-only)
│   ├── ecs.tf           # cluster, ALB, target group, security groups, task def, service
│   ├── outputs.tf       # prints the browsable ALB URL
│   └── .gitignore
└── README.md            # this file
```

---

## Deploy

Prerequisites: AWS CLI configured (`aws configure`), Terraform ≥ 1.6.

```bash
cd ecs/terraform
terraform init
terraform plan
terraform apply        # type: yes  (~2-3 minutes)

terraform output -raw alb_dns_name   # open this URL in a browser
```

Open the printed URL. It may return a `503`/connection error for the first
15-30 seconds while the target group health check warms up — refresh once
the task is `RUNNING` and `HEALTHY`:

```bash
aws ecs describe-services \
  --cluster "$(terraform output -raw cluster_name)" \
  --services "$(terraform output -raw service_name)" \
  --query 'services[0].{status:status,running:runningCount,desired:desiredCount}'
```

You should see **"This is Deployed in ECS"**, with the subtitle confirming
the page was fetched from S3.

### Tear down

```bash
terraform destroy      # type: yes
```

Everything here — ALB, target group, ECS service/cluster, task definitions,
IAM roles, security groups, VPC, and the S3 bucket (`force_destroy = true`)
— is a Terraform-managed resource, so **destroy order is fully automatic**.
Unlike the EKS demo, there is no manual "delete the k8s Service before
`terraform destroy`" step required here.

---

## Corner cases this stack already handles

- **No NAT Gateway cost**: tasks run in public subnets with
  `assign_public_ip = true`, sufficient for pulling public images and
  calling the S3 API. (Trade-off: task ENIs get public IPs. For a
  production posture, switch to private subnets + NAT Gateway or VPC
  interface endpoints for S3/ECR/CloudWatch Logs — flagged here so the
  migration agent doesn't have to guess which posture to replicate.)
- **No custom Docker build/push required**: uses the ECS-native
  multi-container "init sidecar" pattern (`fetch-content` → `web` via
  `dependsOn`/`condition=SUCCESS`) with two public images, instead of
  baking S3 access into a custom image. Reduces the demo to `terraform
  apply` only, same as the Lambda case.
- **Least-privilege IAM**: execution role (image pull + logs) and task
  role (S3 read of exactly one object) are separate roles — the running
  container never has more than `s3:GetObject` on
  `index.html` + `s3:ListBucket` on the bucket.
- **Security group scoping**: ALB SG allows public `:80` only; the task SG
  allows `:80` **only from the ALB SG** (not `0.0.0.0/0`).
- **Deployment safety**: `deployment_circuit_breaker { enable = true,
  rollback = true }` — a bad task definition automatically rolls back
  instead of leaving the service flapping.
- **Health check grace period** (30s) accounts for the sidecar fetch step
  before the ALB starts health-checking the `web` container.
- **`force_destroy = true`** on the S3 bucket and
  `enable_deletion_protection = false` on the ALB — both deliberate so a
  demo teardown never gets stuck; flip both for production use.
- **Distinct CIDR** (`10.1.0.0/16`) from the EKS demo's `10.0.0.0/16` so
  both stacks can be deployed simultaneously in the same account without a
  VPC peering/CIDR conflict.

---

## GCP-side: IAP setup after migration (Cloud Run target)

This section assumes the migration agent's recommended target is **Cloud
Run** (the closest analog to a single ECS Fargate service). If the target
is **GKE** instead, see the note at the end — the IAP mechanics for GKE
Ingress are different (Ingress-native IAP annotation vs. a manually wired
external HTTPS Load Balancer).

The goal, mirroring the IAP pattern already used for the Lambda→Cloud Run
and EKS→GKE demos: put **Identity-Aware Proxy in front of the migrated
Cloud Run service**, reachable over HTTPS on a reserved static IP (using
`nip.io` so no real domain/DNS is required), with no direct public access
to the raw Cloud Run URL.

### 0. Prerequisites

```bash
export PROJECT_ID=<your-gcp-project-id>
export REGION=us-central1
export SERVICE=hello-ecs
export DOMAIN_TAG=hello-ecs   # cosmetic label used in resource names

gcloud config set project "$PROJECT_ID"

gcloud services enable \
  run.googleapis.com \
  compute.googleapis.com \
  iap.googleapis.com \
  cloudresourcemanager.googleapis.com \
  --project "$PROJECT_ID"
```

### 1. Deploy the migrated app to Cloud Run

(This is the output of the migration agent's code-gen step — shown here for
completeness; skip if already deployed.)

```bash
gcloud run deploy "$SERVICE" \
  --image="gcr.io/$PROJECT_ID/$SERVICE:latest" \
  --region="$REGION" \
  --platform=managed \
  --no-allow-unauthenticated \
  --ingress=internal-and-cloud-load-balancing
```

`--ingress=internal-and-cloud-load-balancing` is the key corner case here:
it **blocks the direct `*.run.app` URL from the public internet**, so the
*only* public path into the service is through the Load Balancer + IAP
you're about to create. Skipping this flag is the most common way IAP
setups get accidentally bypassed.

### 2. Reserve a static IP and derive the nip.io domain

```bash
gcloud compute addresses create "${DOMAIN_TAG}-ip" --global --project "$PROJECT_ID"

export STATIC_IP=$(gcloud compute addresses describe "${DOMAIN_TAG}-ip" \
  --global --format='value(address)' --project "$PROJECT_ID")

export NIP_DOMAIN="${STATIC_IP}.nip.io"
echo "Domain: $NIP_DOMAIN"
```

### 3. Serverless NEG → backend service (IAP-enabled)

```bash
gcloud compute network-endpoint-groups create "${DOMAIN_TAG}-neg" \
  --region="$REGION" \
  --network-endpoint-type=serverless \
  --cloud-run-service="$SERVICE" \
  --project "$PROJECT_ID"

gcloud compute backend-services create "${DOMAIN_TAG}-backend" \
  --global \
  --load-balancing-scheme=EXTERNAL_MANAGED \
  --project "$PROJECT_ID"

gcloud compute backend-services add-backend "${DOMAIN_TAG}-backend" \
  --global \
  --network-endpoint-group="${DOMAIN_TAG}-neg" \
  --network-endpoint-group-region="$REGION" \
  --project "$PROJECT_ID"
```

### 4. OAuth consent screen + client (one-time, Console step)

IAP requires an OAuth consent screen and an OAuth 2.0 Client ID for the
project. **This one step cannot be fully scripted via `gcloud`** — it must
be created once via Console:
`APIs & Services → OAuth consent screen` (Internal, if using a
Google Workspace org, or External + test users otherwise), then
`APIs & Services → Credentials → Create OAuth client ID → Web application`.

Once created, capture the client ID/secret:

```bash
export IAP_CLIENT_ID=<oauth-client-id>
export IAP_CLIENT_SECRET=<oauth-client-secret>
```

### 5. Enable IAP on the backend service

```bash
gcloud compute backend-services update "${DOMAIN_TAG}-backend" \
  --global \
  --iap=enabled,oauth2-client-id="$IAP_CLIENT_ID",oauth2-client-secret="$IAP_CLIENT_SECRET" \
  --project "$PROJECT_ID"
```

### 6. Allow the Load Balancer to invoke Cloud Run

Because `--ingress=internal-and-cloud-load-balancing` already blocks
direct public access, granting `run.invoker` to `allUsers` here is safe —
**IAP**, not Cloud Run IAM, is what gates public access on this path:

```bash
gcloud run services add-iam-policy-binding "$SERVICE" \
  --region="$REGION" \
  --member="allUsers" \
  --role="roles/run.invoker" \
  --project "$PROJECT_ID"
```

### 7. Managed SSL certificate for the nip.io domain

```bash
gcloud compute ssl-certificates create "${DOMAIN_TAG}-cert" \
  --domains="$NIP_DOMAIN" \
  --global \
  --project "$PROJECT_ID"
```

Provisioning a Google-managed cert typically takes 10-20 minutes after DNS
resolves (nip.io resolves instantly since it just echoes the IP back, so
the only wait here is Google's own issuance).

### 8. URL map → target HTTPS proxy → global forwarding rule

```bash
gcloud compute url-maps create "${DOMAIN_TAG}-urlmap" \
  --default-service="${DOMAIN_TAG}-backend" \
  --project "$PROJECT_ID"

gcloud compute target-https-proxies create "${DOMAIN_TAG}-https-proxy" \
  --url-map="${DOMAIN_TAG}-urlmap" \
  --ssl-certificates="${DOMAIN_TAG}-cert" \
  --project "$PROJECT_ID"

gcloud compute forwarding-rules create "${DOMAIN_TAG}-fwd-rule" \
  --global \
  --target-https-proxy="${DOMAIN_TAG}-https-proxy" \
  --address="${DOMAIN_TAG}-ip" \
  --ports=443 \
  --project "$PROJECT_ID"
```

### 9. Grant users access through IAP

```bash
gcloud iap web add-iam-policy-binding \
  --resource-type=backend-services \
  --service="${DOMAIN_TAG}-backend" \
  --member="user:someone@yourdomain.com" \
  --role="roles/iap.httpsResourceAccessor" \
  --project "$PROJECT_ID"

# Or for a whole Google Group:
gcloud iap web add-iam-policy-binding \
  --resource-type=backend-services \
  --service="${DOMAIN_TAG}-backend" \
  --member="group:team@yourdomain.com" \
  --role="roles/iap.httpsResourceAccessor" \
  --project "$PROJECT_ID"
```

### 10. Test

```bash
echo "https://${NIP_DOMAIN}"
```

Open in a browser. You should be redirected to a Google sign-in prompt
(IAP), and after authenticating as a granted user, land on the migrated
"This is Deployed in ECS" page served from Cloud Run.

### Corner cases specific to IAP + serverless NEG

- **Cert provisioning delay**: the LB will serve `502`/cert-not-ready
  errors for several minutes after step 7 until the managed cert finishes
  provisioning — this is expected, not a misconfiguration.
- **`EXTERNAL_MANAGED` vs `EXTERNAL`** load balancing scheme: serverless
  NEGs require the newer Global external Application Load Balancer
  (`EXTERNAL_MANAGED`); the classic scheme does not support serverless
  NEG backends.
- **IAP + Cloud Run ingress must be paired**: enabling IAP on the backend
  service *without* also setting `--ingress=internal-and-cloud-load-balancing`
  on the Cloud Run service leaves the direct `*.run.app` URL exposed as an
  IAP bypass — always set both together.
- **`roles/run.invoker` on `allUsers`** looks alarming in isolation but is
  the documented, correct pattern here specifically *because* ingress is
  locked to LB-only traffic — don't skip the ingress flag and don't skip
  this binding; both are required together.
- **Teardown order**: delete the forwarding rule and target HTTPS proxy
  before the backend service/NEG, and the backend service before the
  Cloud Run service if decommissioning entirely — reverse of creation
  order, same principle as any GCP LB stack.

### If the target is GKE instead of Cloud Run

The mechanics differ: GKE typically fronts IAP via either
(a) an Ingress with the `iap.enabled` annotation on a `BackendConfig`
resource pointing at the Service, using the same OAuth client from step 4,
or (b) the same manual backend-service pattern above but with a
zonal/instance-group NEG (`--neg-type=GCE_VM_IP_PORT` or container-native
NEG) instead of the serverless NEG in step 3. The OAuth consent/client
setup (step 4) and the `roles/iap.httpsResourceAccessor` grant (step 9) are
identical either way — only the NEG type and backend wiring change.

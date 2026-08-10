# hello-eks — Amazon EKS workload (source for AWS→GCP migration)

A minimal Kubernetes app running on **Amazon EKS** that serves a single page:
**"This is Deployed in EKS"** — reachable via a public **LoadBalancer URL** you
can open in a browser and show to a customer.

This is the **EKS → GKE** counterpart to the Lambda → Cloud Run workload in this
repo. The migration agent reads this Terraform + manifests to build its plan,
deploy the same app to GKE (showing **"This is Deployed in GKE"**), shift traffic
to GKE, and cut it off from EKS.

---

## Workload summary (for the migration agent)

| Attribute | Value |
|---|---|
| Workload type | Amazon EKS (managed Kubernetes) |
| Cluster name | `hello-eks` |
| Kubernetes version | `1.30` |
| Node group | managed, `t3.small` × 2 (min 1 / max 3) |
| Namespace | `hello` |
| App | `hello-eks` Deployment, 2 replicas, `nginx:1.27-alpine` |
| Content | Static HTML from a ConfigMap (`text/html`), no dependencies |
| Expose | `Service type=LoadBalancer` (AWS NLB, internet-facing, port 80) |
| State | Stateless — no PVC, no database, no secrets |
| Region | `ap-south-1` (default; override via `aws_region`) |

**GCP migration target:** GKE (Autopilot or Standard). The Deployment +
ConfigMap map 1:1 to GKE; the `Service type=LoadBalancer` maps to a GCP
external load balancer. Because the workload is stateless with a single HTTP
entry point and no dependencies, it is a clean, low-risk cluster-to-cluster lift.

---

## Repository layout

```
eks/
├── terraform/            # stands up the EKS cluster
│   ├── versions.tf
│   ├── variables.tf
│   ├── vpc.tf            # VPC + public/private subnets (official module)
│   ├── eks.tf            # EKS cluster + managed node group (official module)
│   ├── outputs.tf
│   └── .gitignore
└── k8s/                  # the demo app
    ├── namespace.yaml
    ├── configmap.yaml    # the "This is Deployed in EKS" HTML page
    ├── deployment.yaml   # nginx serving the ConfigMap
    └── service.yaml      # LoadBalancer -> browsable public URL
```

---

## Deploy (once your AWS key + secret are configured)

Prerequisites: AWS CLI configured (`aws configure`), Terraform ≥ 1.6, and
`kubectl` installed.

### 1. Create the cluster
```bash
cd eks/terraform
terraform init
terraform apply        # type: yes  (~15 min for the control plane + nodes)
```

### 2. Point kubectl at the new cluster
```bash
# terraform prints this exact command as the "configure_kubectl" output
aws eks update-kubeconfig --region ap-south-1 --name hello-eks
kubectl get nodes      # should list 2 Ready nodes
```

### 3. Deploy the app
```bash
cd ../k8s
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

### 4. Get the browsable URL
```bash
kubectl get svc hello-eks -n hello -w
# wait for EXTERNAL-IP to change from <pending> to an AWS hostname, e.g.
#   a1b2c3...elb.ap-south-1.amazonaws.com
```
Open that hostname in a browser → **"This is Deployed in EKS"**. 🎉

---

## Tear down

```bash
kubectl delete -f k8s/          # remove the LB first (frees the AWS ELB)
cd eks/terraform && terraform destroy
```

> Delete the Kubernetes Service **before** `terraform destroy`, otherwise the
> orphaned AWS load balancer can block VPC deletion.

---

## Notes

- Terraform state is **local** by default and git-ignored — never commit it.
- The NLB is internet-facing for an easy demo. Restrict or make internal for real use.
- Kept intentionally stateless and dependency-free so the EKS→GKE migration is a
  clean before/after: same app, same page text swapped to "This is Deployed in GKE".

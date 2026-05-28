# Project Bedrock — InnovateMart EKS Deployment

Production-grade Kubernetes infrastructure on AWS EKS for InnovateMart's retail microservices platform.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS us-east-1                            │
│                                                                 │
│  ┌──────────────── project-bedrock-vpc ───────────────────┐    │
│  │                                                         │    │
│  │  Public Subnets (us-east-1a / us-east-1b)              │    │
│  │  ┌─────────────┐  ┌─────────────┐                      │    │
│  │  │  NAT GW  1  │  │  NAT GW  2  │  ← ALB (internet)   │    │
│  │  └─────────────┘  └─────────────┘                      │    │
│  │                                                         │    │
│  │  Private Subnets (us-east-1a / us-east-1b)             │    │
│  │  ┌──────────────────────────────────┐                  │    │
│  │  │     EKS Cluster (v1.34)          │                  │    │
│  │  │  ┌────────────────────────────┐  │                  │    │
│  │  │  │   retail-app namespace     │  │                  │    │
│  │  │  │  ui / catalog / orders     │  │                  │    │
│  │  │  │  cart / rabbitmq / redis   │  │                  │    │
│  │  │  └────────────────────────────┘  │                  │    │
│  │  └──────────────────────────────────┘                  │    │
│  │                                                         │    │
│  │  ┌──────────────┐  ┌──────────────┐                    │    │
│  │  │  MySQL RDS   │  │ Postgres RDS │  ← private only    │    │
│  │  └──────────────┘  └──────────────┘                    │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│  DynamoDB (cart)   CloudWatch (logs)   S3 + Lambda (assets)    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

| Tool | Version |
|---|---|
| Terraform | >= 1.9.0 |
| AWS CLI | >= 2.x |
| kubectl | >= 1.30 |
| helm | >= 3.15 |

---

## Quick Start

### 1. Bootstrap remote state

```bash
export STUDENT_ID="your-student-id"
chmod +x scripts/bootstrap-backend.sh
./scripts/bootstrap-backend.sh
```

### 2. Configure backend

Edit `terraform/backend.tf` — replace `<YOUR-STUDENT-ID>` with your actual student ID.

### 3. Set variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars — set student_id at minimum
```

### 4. Initialise and deploy

```bash
cd terraform

# Initialise with remote state
terraform init

# Pass 1 — core infrastructure (VPC, EKS, RDS, IAM, Lambda)
terraform apply \
  -target=module.vpc \
  -target=module.eks \
  -target=module.rds \
  -target=module.dynamodb \
  -target=module.iam \
  -target=module.serverless \
  -var="student_id=$STUDENT_ID"

# Pass 2 — platform + app (Helm releases, Ingress, K8s resources)
terraform apply -var="student_id=$STUDENT_ID"
```

### 5. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name project-bedrock-cluster
kubectl get pods -n retail-app
```

---

## Required Naming Conventions (Grader)

| Resource | Value |
|---|---|
| AWS Region | `us-east-1` |
| EKS Cluster | `project-bedrock-cluster` |
| VPC Name Tag | `project-bedrock-vpc` |
| App Namespace | `retail-app` |
| IAM User | `bedrock-dev-view` |
| S3 Bucket | `bedrock-assets-<student_id>` |
| Lambda | `bedrock-asset-processor` |
| Tag | `Project: karatu-2025-capstone` |

---

## Required Terraform Outputs

Run `terraform output` after apply to retrieve:

| Output | Description |
|---|---|
| `cluster_endpoint` | EKS API server URL |
| `cluster_name` | `project-bedrock-cluster` |
| `region` | `us-east-1` |
| `vpc_id` | VPC resource ID |
| `assets_bucket_name` | `bedrock-assets-<student_id>` |

Sensitive outputs (access keys, passwords):
```bash
terraform output -raw dev_user_access_key_id
terraform output -raw dev_user_secret_access_key
terraform output -raw dev_user_console_password
```

---

## File Structure

```
project-bedrock/
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml   # PR → plan + comment
│       └── terraform-apply.yml  # merge to main → apply
├── terraform/
│   ├── backend.tf               # S3 remote state
│   ├── versions.tf              # Provider requirements
│   ├── variables.tf             # Input variables
│   ├── main.tf                  # Root module (wires everything)
│   ├── outputs.tf               # Required + bonus outputs
│   ├── terraform.tfvars.example # Safe example config
│   └── modules/
│       ├── vpc/                 # VPC, subnets, NAT GWs
│       ├── eks/                 # EKS cluster, nodes, OIDC, add-ons
│       ├── rds/                 # MySQL + PostgreSQL + Secrets Manager
│       ├── dynamodb/            # Cart table
│       ├── iam/                 # Dev user, IRSA roles, Lambda role
│       └── serverless/          # S3 bucket, Lambda, S3 notification
├── k8s/
│   ├── rbac/
│   │   └── dev-view-clusterrolebinding.yaml
│   └── ingress/
│       └── retail-ui-ingress.yaml
└── scripts/
    └── bootstrap-backend.sh     # One-time backend bucket creation
```

---

## CI/CD Setup (GitHub Actions)

### Repository Secrets Required

| Secret | Description |
|---|---|
| `AWS_ROLE_ARN` | OIDC IAM role ARN for GitHub Actions |
| `STUDENT_ID` | Your student ID (for bucket naming) |

### OIDC Setup (Recommended)
Follow: https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services

### Workflow Behaviour
- **Pull Request** → `terraform plan` runs, output posted as PR comment
- **Merge to main** → `terraform apply` runs (two-pass: infra then platform)

---

## Developer Access Verification

```bash
# Configure kubectl as bedrock-dev-view
aws configure --profile bedrock-dev-view
# Enter Access Key ID and Secret from terraform outputs

aws eks update-kubeconfig \
  --region us-east-1 \
  --name project-bedrock-cluster \
  --profile bedrock-dev-view

# Should SUCCEED
kubectl get pods -n retail-app

# Should FAIL (Forbidden)
kubectl delete pod <any-pod-name> -n retail-app
```

---

## Observability

| Log Group | Contents |
|---|---|
| `/aws/eks/project-bedrock-cluster/cluster` | Control plane (API, Audit, Authenticator, etc.) |
| `/aws/containerinsights/project-bedrock-cluster/application` | Application container logs |
| `/aws/lambda/bedrock-asset-processor` | Lambda invocation logs |
| `/aws/vpc/project-bedrock-vpc/flow-logs` | VPC flow logs |

---

## Testing the Lambda

```bash
# Upload a test file using bedrock-dev-view credentials
aws s3 cp test-image.jpg s3://bedrock-assets-<student_id>/test-image.jpg \
  --profile bedrock-dev-view

# Check Lambda was triggered
aws logs tail /aws/lambda/bedrock-asset-processor --follow
# Expected log line: "Image received: test-image.jpg"
```

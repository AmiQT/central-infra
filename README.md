# Central-Infra: Enterprise-Grade Infrastructure-as-Code (IaC) Sandbox

**A modular, multi-tier Kubernetes platform with a pluggable cluster layer that runs the same stack locally (k3d) or on AWS (k3s on EC2).**

This project provisions a production-style Kubernetes environment, orchestrated fully through **Terraform** and **Helm**. It features isolated architectural layers covering Cluster Provisioning, Ingress Networking, Observability (Prometheus/Grafana), Least-Privilege RBAC, and secure workload deployments — plus a **keyless GitHub Actions CI/CD pipeline** that builds to **Amazon ECR** and deploys to the cluster.

The cluster layer is **pluggable**: `cluster_mode = "k3d"` spins up a local cluster with an integrated container registry, while `cluster_mode = "aws-ec2"` provisions single-node k3s on EC2 — keyless (SSM, no SSH), with the same Layer 2-4 stack deploying unchanged on top. This demonstrates a clean local ↔ cloud (hybrid) story.

---

## Architecture & Layers

To prevent Terraform provider dependency deadlocks, the infrastructure is broken into **isolated layers**, allowing independent provisioning and tear-downs:

- **Layer 0: Bootstrap (`layer0-bootstrap`)** *(AWS, optional)*
  - Provisions the **remote state backend** (S3 with versioning + encryption, DynamoDB locking).
  - Creates the **ECR** repository and a **GitHub OIDC role** so CI authenticates **without static keys**.

- **Layer 1: Cluster (`layer1-cluster`)** — **pluggable** via `cluster_mode`
  - `k3d` mode: local cluster (1 Server, 2 Agents) + integrated registry (`localhost:5001`), provisioned by shellcheck-clean bash scripts.
  - `aws-ec2` mode: single-node **k3s on EC2** — keyless (SSM Session Manager, **no SSH**), publishes its kubeconfig to SSM Parameter Store.
  - Either way, emits a host `kubeconfig.yaml` so Layers 2-4 consume it transparently.

- **Layer 2: Platform (`layer2-platform`)**
  - Installs core platform extensions via **Helm** with pinned chart versions for absolute stability.
  - **Networking:** NGINX Ingress Controller for traffic routing.
  - **Observability:** `kube-prometheus-stack` (Prometheus & Grafana integrated).

- **Layer 3: Apps & Security (`layer3-apps`)**
  - Configures dedicated namespaces (e.g., `gopher-ops`).
  - Sets up **Least-Privilege RBAC** rules (scoping roles and bindings at the Namespace level rather than Cluster-wide).

- **Layer 4: Workloads (`layer4-workloads`)**
  - Deploys application containers (e.g., `talent-api`) with active **Liveness** and **Readiness probes** for high availability.
  - Features hardcoded pod security contexts and Prometheus scraping annotations.
  - Exposes workloads through standard NGINX Ingress hosts (`talent-api.local`).

---

## Prerequisites

Before you begin, ensure you have the following installed on your machine:
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Running)
- [k3d](https://k3d.io/)
- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- Make (optional, for running the orchestration tasks)
- For **AWS mode** only: [AWS CLI](https://aws.amazon.com/cli/) configured with credentials (`aws configure`)

---

## Orchestration with Makefile

Manage the entire multi-tier cluster lifecycle using a single command from the root directory.

| Command | Action |
| :--- | :--- |
| `make init` | Run `terraform init` across all layers sequentially |
| `make validate` | Validate the syntax of all Terraform layers |
| `make up` | Provision the entire environment (Layer 1 ➔ 4) in sequential order |
| `make down` | Tear down the entire environment (Layer 4 ➔ 1) in reverse order to prevent deadlocks |
| `make status` | Query nodes, pods, and ingress rules across the cluster |
| `make clean` | Remove local Terraform state backup files |

---

## Local Container Registry Workflow

This platform features an integrated local registry on port `5001` (associated as `k3d-central-infra-registry.localhost:5001`). You can build, push, and pull images without using any external registry!

### Step 1: Build and Tag your application image
```bash
docker build -t localhost:5001/talent-api:latest .
```

### Step 2: Push to the Local Registry
```bash
docker push localhost:5001/talent-api:latest
```

### Step 3: Deploy to the Cluster
Update your Kubernetes deployment in Layer 4 (`layer4-workloads/variables.tf` or `main.tf`) to use `k3d-central-infra-registry.localhost:5001/talent-api:latest` as the image name. Kubernetes will pull it instantly from the local registry!

---

## Cloud / Hybrid Mode (AWS)

Run the **same** stack on AWS instead of locally — no code changes to Layers 2-4.

1. **Bootstrap** the foundation (remote state, ECR, OIDC):
   ```bash
   cd layer0-bootstrap && terraform init && terraform apply
   ```
2. **Point Layer 1 at AWS** — copy the example tfvars and set your IP:
   ```bash
   cd ../layer1-cluster
   cp terraform.tfvars.example terraform.tfvars   # set cluster_mode = "aws-ec2" and admin_cidr = "<your-ip>/32"
   ```
3. **Provision** — the EC2 node self-bootstraps k3s via cloud-init (no SSH):
   ```bash
   terraform apply
   terraform output app_url        # e.g. http://<node-ip>/  ← never hardcode this; it changes per rebuild
   ```

**Security posture:** no SSH (access via SSM Session Manager), the kube API (6443) is restricted to `admin_cidr`, only port 80 is public, and the node pulls from ECR using its IAM instance role (no static keys).

> Free-tier note: a 1 GB `t3.micro` runs k3s + a lightweight workload. The full observability stack (Prometheus + ArgoCD) is intended for local k3d or a larger instance.

---

## CI/CD Pipeline

Two keyless GitHub Actions workflows (`.github/workflows/`):

- **`ci.yml`** — on every PR/push: `terraform fmt` + `validate` (all layers), `shellcheck` the bash provisioners, and a **Trivy** IaC misconfiguration scan.
- **`cd-app.yml`** — on changes under `app/`: authenticate via **OIDC** (no static AWS keys), build the image, push to **ECR** with a git-SHA tag, **Trivy** image scan, then deploy to k3s via **SSM Run Command** — CI never holds a kubeconfig and the kube API is never exposed to CI.

The AWS account ID is **not** committed: the role ARN comes from the `AWS_ROLE_ARN` repo variable and the ECR registry is derived at runtime.

---

## Author
**AmiQT**  
*Platform Engineer & SRE*
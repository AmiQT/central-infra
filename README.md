# Central-Infra: Enterprise-Grade Infrastructure-as-Code (IaC) Sandbox

🚀 **A modular, multi-tier Kubernetes environment built locally for production simulation and testing.**

This project simulates a production-grade Kubernetes environment on a local machine using **k3d**, orchestrated fully through **Terraform** and **Helm**. It features isolated architectural layers, encompassing Cluster Provisioning with an integrated Local Container Registry, Ingress Networking, Observability (Prometheus/Grafana), Least-Privilege RBAC rules, and secure workload deployments.

---

## 🏗️ Architecture & Layers

To prevent Terraform provider dependency deadlocks, the infrastructure is broken down into **4 distinct layers**, allowing independent provisioning and tear-downs:

- **Layer 1: Cluster (`layer1-cluster`)**
  - Automates **k3d** cluster creation (1 Server, 2 Agents).
  - Provisions a **Local Container Registry** (`localhost:5001`) natively linked to the cluster.
  - Dynamically extracts and rewrites `kubeconfig.yaml` to ensure seamless `kubectl` access on the host machine.

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

## 🛠️ Prerequisites

Before you begin, ensure you have the following installed on your machine:
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Running)
- [k3d](https://k3d.io/)
- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- Make (optional, for running the orchestration tasks)

---

## 🚀 Orchestration with Makefile

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

## 🐳 Local Container Registry Workflow

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

## 👨‍💻 Author
**AmiQT**  
*Platform Engineer & SRE*
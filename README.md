# Central-Infra: Centralized Infrastructure-as-Code (IaC) Sandbox

🚀 **A modular, multi-tier Kubernetes environment built locally for production simulation and testing.** 

This project simulates a production-grade Kubernetes environment on a local machine using **k3d**, orchestrated fully through **Terraform** and **Helm**. It features isolated architectural layers, encompassing Cluster Provisioning, Ingress Networking, Observability (Prometheus/Grafana), and customized pre-configured RBAC rules.

---

## 🏗️ Architecture & Layers

To prevent Terraform provider dependency deadlocks, the infrastructure is broken down into **4 distinct layers**, allowing independent provisioning and tear-downs:

- **Layer 1: Cluster (`layer1-cluster`)**
  - Automates **k3d** cluster creation.
  - Provisions a simulated distributed environment (1 Server Node, 2 Agent Nodes).
  - Dynamically extracts and rewrites the `kubeconfig.yaml` to ensure seamless `kubectl` access on the host machine.

- **Layer 2: Platform (`layer2-platform`)**
  - Installs core cluster extensions via **Helm**.
  - **Networking:** NGINX Ingress Controller for traffic routing.
  - **Observability:** `kube-prometheus-stack` (Prometheus & Grafana integrated).

- **Layer 3: Apps & Security (`layer3-apps`)**
  - Configures **Namespaces** (e.g., `gopher-ops`).
  - Sets up **RBAC** (Role-Based Access Control) including custom ServiceAccounts, ClusterRoles, and ClusterRoleBindings for bot and operator accesses.

- **Layer 4: Workloads (`layer4-workloads`)**
  - Contains Kubernetes Deployments and Services for target applications.
  - Showcases proof-of-concept deployment utilizing Docker images directly on the cluster.

---

## 🛠️ Prerequisites

Before you begin, ensure you have the following installed on your machine:
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Running)
- [k3d](https://k3d.io/)
- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- Helm (optional, as Terraform utilizes the Helm provider internally)

---

## 🚀 Getting Started

Deploy the sandbox by initializing and applying Terraform configurations in sequential order. 

**Note for Windows Users:** The `kubeconfig.yaml` is dynamically generated and fixed inside `layer1-cluster` to map to `127.0.0.1`. Export it using `$env:KUBECONFIG="<path-to-layer1>/kubeconfig.yaml"` before querying the cluster.

### Step 1: Provision the Cluster
```bash
cd layer1-cluster
terraform init
terraform apply -auto-approve
```

### Step 2: Deploy Platform Services (Ingress & Observability)
```bash
cd ../layer2-platform
terraform init
terraform apply -auto-approve
```

### Step 3: Setup RBAC & App Namespaces
```bash
cd ../layer3-apps
terraform init
terraform apply -auto-approve
```

### Step 4: Deploy Workloads
```bash
cd ../layer4-workloads
terraform init
terraform apply -auto-approve
```

---

## 🔍 Verifying the Setup

Check if the pods in the system are running smoothly:
```bash
kubectl get pods -A
```
Access the Kubernetes Web Dashboard or Grafana by port-forwarding their respective services.

---

## 🧹 Clean Up

To completely wipe out the environment and free up local resources, destroy the layers in **reverse order**:

```bash
cd layer4-workloads && terraform destroy -auto-approve
cd ../layer3-apps && terraform destroy -auto-approve
cd ../layer2-platform && terraform destroy -auto-approve
cd ../layer1-cluster && terraform destroy -auto-approve
```

*(Finally, you can also run `k3d cluster delete central-infra-lab` recursively if needed).*

---

### 👨‍💻 Author
**Noorazami**
*Platform Engineer & SRE*
.PHONY: init validate up down status clean

init:
	@echo "=== Initializing all Terraform Layers ==="
	cd layer1-cluster && terraform init
	cd layer2-platform && terraform init
	cd layer3-apps && terraform init
	cd layer4-workloads && terraform init

validate:
	@echo "=== Validating all Terraform Layers ==="
	cd layer1-cluster && terraform validate
	cd layer2-platform && terraform validate
	cd layer3-apps && terraform validate
	cd layer4-workloads && terraform validate

up:
	@echo "=== Deploying Layer 1: Cluster ==="
	cd layer1-cluster && terraform apply -auto-approve
	@echo "=== Deploying Layer 2: Platform Services ==="
	cd layer2-platform && terraform apply -auto-approve
	@echo "=== Deploying Layer 3: Apps & Security ==="
	cd layer3-apps && terraform apply -auto-approve
	@echo "=== Deploying Layer 4: Workloads ==="
	cd layer4-workloads && terraform apply -auto-approve

down:
	@echo "=== Destroying Layer 4: Workloads ==="
	cd layer4-workloads && terraform destroy -auto-approve
	@echo "=== Destroying Layer 3: Apps & Security ==="
	cd layer3-apps && terraform destroy -auto-approve
	@echo "=== Destroying Layer 2: Platform Services ==="
	cd layer2-platform && terraform destroy -auto-approve
	@echo "=== Destroying Layer 1: Cluster ==="
	cd layer1-cluster && terraform destroy -auto-approve

status:
	@echo "=== Checking Kubernetes Cluster Status ==="
	kubectl get nodes -o wide
	@echo "=== Checking Pods in All Namespaces ==="
	kubectl get pods -A
	@echo "=== Checking Ingress Resources ==="
	kubectl get ingress -A

clean:
	@echo "=== Cleaning up Terraform state backups ==="
	rm -f **/*.tfstate.backup

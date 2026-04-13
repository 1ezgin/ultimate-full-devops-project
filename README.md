🏦 Ultimate Bank Application Deployment (End-to-End DevOps Project)
This repository contains a complete automation of the software development lifecycle (SDLC) for a banking application — from Infrastructure as Code (IaC) to automated deployment in AWS EKS using GitOps practices.

🛠 Technology Stack
Cloud: AWS (EKS, EC2, ELB, EBS, IAM)

Infrastructure: Terraform

CI/CD Orchestration: Jenkins (Pipeline-as-Code)

Artifact Management: Sonatype Nexus (Storing build artifacts)

Containerization: Docker & Docker Hub

Orchestration: Kubernetes (K8s)

Security & Quality: SonarQube, Trivy, OWASP Dependency-Check

Networking: Nginx Ingress Controller, Cert-Manager (Let's Encrypt SSL)

Database: MySQL

🏗 Architecture & Workflow
Infrastructure: Provisioning VPC, Subnets, and EKS Cluster via Terraform.

CI Pipeline:

Build: Compile the Java project using Maven.

Static Code Analysis: Quality gates via SonarQube.

Dependency Scanning: Vulnerability check via OWASP Dependency-Check.

Artifact Storage: Uploading the compiled .jar/.war files to Nexus Repository Manager.

Containerization: Building a Docker image using the artifact from Nexus.

Image Scanning: Security audit via Trivy.

Registry: Pushing the secured image to Docker Hub.

CD Pipeline:

Automation: Triggered via GitHub Webhooks.

Deployment: Applying K8s manifests using kubectl and withKubeConfig.

Scalability: Configured HPA (Horizontal Pod Autoscaler) for high availability.

Traffic Management: Routing through Nginx Ingress with SSL termination.

🚀 Getting Started
1. Infrastructure Provisioning
Bash
cd Mega-Project-Terraform-main
terraform init
terraform apply -auto-approve
2. Jenkins Configuration
Plugins: Install Docker Pipeline, Kubernetes CLI, SonarQube Scanner, Nexus Artifact Uploader.

Credentials:

1ezgin: GitHub PAT.

docker-hub-creds: Docker Hub credentials.

nexus-creds: Credentials for Nexus Repository.

k8-token: K8s Service Account Token.

sonar-token: SonarQube Auth Token.

3. One-Time Cluster Setup (Infra Server)
Bash
# Install Nginx Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# Install Cert-Manager & ClusterIssuer
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.12.2/cert-manager.yaml
kubectl apply -f Manifest/ci.yaml
📈 Final Result
The application is deployed and accessible via the AWS Load Balancer DNS.

Environment: Production-ready EKS Cluster.

Monitoring: HPA active (Targets: CPU > 50%, Memory > 70%).

Artifacts: All versions stored and versioned in Nexus.

🧹 Resource Cleanup
To avoid AWS unexpected costs:

Bash
terraform destroy -auto-approve

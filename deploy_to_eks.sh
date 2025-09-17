#!/bin/bash
set -e

# --- Configuration ---
AWS_REGION="ap-south-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CLUSTER_NAME="hydra-cluster"
ECR_REPO_NAME="hydra-app"
S3_BUCKET_NAME="hydra-phishing-evidence-$ACCOUNT_ID"
ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
IMAGE_URI="$ECR_REGISTRY/$ECR_REPO_NAME:latest"

echo "--- EKS Deployment Script ---"
echo "Using AWS Account ID: $ACCOUNT_ID"

# --- 1. Create EKS Cluster (if it doesn't exist) ---
if ! eksctl get cluster --name $CLUSTER_NAME --region $AWS_REGION > /dev/null 2>&1; then
  echo "Step 1/4: Creating EKS cluster: $CLUSTER_NAME. This will take 15-20 minutes."
  eksctl create cluster \
    --name $CLUSTER_NAME --version 1.28 --region $AWS_REGION \
    --nodegroup-name standard-workers --node-type t3.medium --nodes 2
else
  echo "Step 1/4: EKS cluster '$CLUSTER_NAME' already exists."
fi

# --- 2. Create ECR Repository and Push Image ---
echo "Step 2/4: Building and pushing Docker image to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
aws ecr create-repository --repository-name $ECR_REPO_NAME --region $AWS_REGION || echo "ECR repo '$ECR_REPO_NAME' already exists."
docker build -t $ECR_REPO_NAME:latest ./services/app/
docker tag $ECR_REPO_NAME:latest $IMAGE_URI
docker push $IMAGE_URI

# --- 3. Create Kubernetes Secret for AWS Credentials ---
echo "Step 3/4: Creating/updating Kubernetes secret for AWS credentials..."
# This uses the credentials from your AWS CLI configuration
kubectl delete secret aws-credentials --ignore-not-found
kubectl create secret generic aws-credentials \
  --from-literal=AWS_ACCESS_KEY_ID=$(aws configure get default.aws_access_key_id) \
  --from-literal=AWS_SECRET_ACCESS_KEY=$(aws configure get default.aws_secret_access_key) \
  --from-literal=AWS_REGION=$AWS_REGION

# --- 4. Update and Apply Kubernetes Manifests ---
echo "Step 4/4: Updating and applying Kubernetes manifests..."

# Create temporary copies of manifests to substitute variables
# This is safer than editing your source files
sed "s|YOUR_AWS_ACCOUNT_ID.dkr.ecr.YOUR_AWS_REGION.amazonaws.com/hydra-app:latest|$IMAGE_URI|g" infra/k8s/deployment.yaml | \
sed "s|hydra-phishing-evidence-YOUR_AWS_ACCOUNT_ID|$S3_BUCKET_NAME|g" > /tmp/deployment.yaml

kubectl apply -f /tmp/deployment.yaml
kubectl apply -f infra/k8s/service.yaml
kubectl apply -f infra/k8s/hpa.yaml

echo "--- Deployment Complete ---"
echo "To find your application URL, run:"
echo "kubectl get service hydra-app-service --watch"
#!/bin/bash
set -e

# --- Configuration: These must match the names used during creation ---
AWS_REGION="ap-south-1"
CLUSTER_NAME="hydra-cluster"
ECR_REPO_NAME="hydra-app"
LAMBDA_FUNCTION_NAME="HydraRekognitionAnalyzer"
IAM_ROLE_NAME="HydraLambdaRekognitionRole"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
S3_BUCKET_NAME="hydra-phishing-evidence-$ACCOUNT_ID"

echo "--- Starting Hydra Project Cleanup ---"
echo "This will permanently delete resources from AWS account: $ACCOUNT_ID in region: $AWS_REGION"
read -p "Are you sure you want to continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Cleanup cancelled."
    exit 1
fi

# 1. Delete the EKS cluster and all its associated resources (VPC, EC2 nodes, etc.)
# This is the longest step and can take 10-15 minutes.
echo "--- Step 1/5: Deleting EKS Cluster ($CLUSTER_NAME) ---"
if eksctl get cluster --name $CLUSTER_NAME --region $AWS_REGION > /dev/null 2>&1; then
    eksctl delete cluster --name $CLUSTER_NAME --region $AWS_REGION --wait
else
    echo "EKS Cluster not found, skipping."
fi

# 2. Delete the ECR repository
# The --force flag will delete all images inside the repository first.
echo "--- Step 2/5: Deleting ECR Repository ($ECR_REPO_NAME) ---"
if aws ecr describe-repositories --repository-names $ECR_REPO_NAME --region $AWS_REGION > /dev/null 2>&1; then
    aws ecr delete-repository --repository-name $ECR_REPO_NAME --region $AWS_REGION --force
else
    echo "ECR Repository not found, skipping."
fi

# 3. Delete the S3 bucket
# The --force flag will delete all objects inside the bucket first.
echo "--- Step 3/5: Emptying and Deleting S3 Bucket ($S3_BUCKET_NAME) ---"
if aws s3 ls "s3://$S3_BUCKET_NAME" --region $AWS_REGION > /dev/null 2>&1; then
    aws s3 rb s3://$S3_BUCKET_NAME --force
else
    echo "S3 Bucket not found, skipping."
fi

# 4. Delete the Lambda function
echo "--- Step 4/5: Deleting Lambda Function ($LAMBDA_FUNCTION_NAME) ---"
if aws lambda get-function --function-name $LAMBDA_FUNCTION_NAME --region $AWS_REGION > /dev/null 2>&1; then
    aws lambda delete-function --function-name $LAMBDA_FUNCTION_NAME --region $AWS_REGION
else
    echo "Lambda Function not found, skipping."
fi

# 5. Detach policies from the IAM role and delete the role
echo "--- Step 5/5: Deleting IAM Role ($IAM_ROLE_NAME) ---"
if aws iam get-role --role-name $IAM_ROLE_NAME > /dev/null 2>&1; then
    POLICY_ARNS=$(aws iam list-attached-role-policies --role-name $IAM_ROLE_NAME --query 'AttachedPolicies[*].PolicyArn' --output text)
    for ARN in $POLICY_ARNS; do
        echo "Detaching policy $ARN from role $IAM_ROLE_NAME"
        aws iam detach-role-policy --role-name $IAM_ROLE_NAME --policy-arn $ARN
    done
    aws iam delete-role --role-name $IAM_ROLE_NAME
else
    echo "IAM Role not found, skipping."
fi

echo "--- ✅ Cleanup Complete ---"

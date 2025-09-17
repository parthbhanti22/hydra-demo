#!/bin/bash
set -e

# --- Configuration ---
# You can change the region if you want
AWS_REGION="ap-south-1"
# The script automatically gets your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
# Generates a globally unique bucket name
S3_BUCKET_NAME="hydra-phishing-evidence-$ACCOUNT_ID"
LAMBDA_FUNCTION_NAME="HydraRekognitionAnalyzer"
IAM_ROLE_NAME="HydraLambdaRekognitionRole"

echo "--- AWS Backend Setup ---"
echo "Using AWS Account ID: $ACCOUNT_ID"
echo "Using Region: $AWS_REGION"

# --- 1. Create S3 Bucket ---
echo "Step 1/5: Creating S3 bucket: $S3_BUCKET_NAME"
aws s3api create-bucket \
  --bucket $S3_BUCKET_NAME \
  --region $AWS_REGION

# --- 2. Create IAM Role and Policy for Lambda ---
echo "Step 2/5: Creating IAM Role: $IAM_ROLE_NAME"
TRUST_POLICY_JSON=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [ { "Effect": "Allow", "Principal": { "Service": "lambda.amazonaws.com" }, "Action": "sts:AssumeRole" } ]
}
EOF
)
ROLE_ARN=$(aws iam create-role --role-name $IAM_ROLE_NAME --assume-role-policy-document "$TRUST_POLICY_JSON" --query 'Role.Arn' --output text)
echo "Attaching policies to role..."
aws iam attach-role-policy --role-name $IAM_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonRekognitionReadOnlyAccess
aws iam attach-role-policy --role-name $IAM_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# --- 3. Create Lambda Function Code ---
echo "Step 3/5: Creating Lambda function code..."
mkdir -p lambda_package
cat <<EOF > lambda_package/lambda_function.py
import json, boto3, urllib.parse
rekognition = boto3.client('rekognition')
def lambda_handler(event, context):
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')
    try:
        print(f"Analyzing {key} from bucket {bucket}")
        response = rekognition.detect_logos(Image={'S3Object': {'Bucket': bucket, 'Name': key}})
        logos = response['LogoResults']
        print("Detected logos: " + str(logos))
        return {'statusCode': 200, 'body': json.dumps(logos)}
    except Exception as e:
        print(f"Error processing object {key}. Error: {e}")
        raise e
EOF

# --- 4. Package and Create Lambda Function ---
echo "Step 4/5: Zipping and creating Lambda function..."
cd lambda_package && zip function.zip lambda_function.py > /dev/null && cd ..
echo "Waiting 10 seconds for IAM role to be ready..."
sleep 10
LAMBDA_ARN=$(aws lambda create-function \
  --function-name $LAMBDA_FUNCTION_NAME --runtime python3.11 \
  --role $ROLE_ARN --handler lambda_function.lambda_handler \
  --zip-file fileb://lambda_package/function.zip \
  --timeout 15 --region $AWS_REGION --query 'FunctionArn' --output text)

# --- 5. Add S3 Trigger to Lambda ---
echo "Step 5/5: Adding S3 trigger to Lambda..."
aws lambda add-permission \
  --function-name $LAMBDA_FUNCTION_NAME --statement-id "S3-trigger" \
  --action "lambda:InvokeFunction" --principal s3.amazonaws.com \
  --source-arn "arn:aws:s3:::$S3_BUCKET_NAME" --region $AWS_REGION
aws s3api put-bucket-notification-configuration \
  --bucket $S3_BUCKET_NAME \
  --notification-configuration '{ "LambdaFunctionConfigurations": [ { "LambdaFunctionArn": "'$LAMBDA_ARN'", "Events": ["s3:ObjectCreated:*"] } ] }'

echo "--- Backend Setup Complete ---"
echo "S3 Bucket: $S3_BUCKET_NAME"
echo "Lambda Function: $LAMBDA_FUNCTION_NAME"
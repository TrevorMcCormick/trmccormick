#!/bin/bash

# PageSpeed Monitoring - Deployment Script
# This script deploys the complete infrastructure to AWS using Terraform

set -e  # Exit on error

echo "=================================="
echo "PageSpeed Monitoring Deployment"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Change to terraform directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"
LAMBDA_DIR="$SCRIPT_DIR/../lambda"

cd "$TERRAFORM_DIR"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}ERROR: terraform.tfvars not found!${NC}"
    echo ""
    echo "Please create terraform.tfvars from terraform.tfvars.example and fill in your values:"
    echo "  cp terraform.tfvars.example terraform.tfvars"
    echo "  # Edit terraform.tfvars with your values"
    echo ""
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}ERROR: AWS CLI is not installed${NC}"
    echo "Install it from: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}ERROR: Terraform is not installed${NC}"
    echo "Install it from: https://www.terraform.io/downloads.html"
    exit 1
fi

# Check AWS credentials
echo -e "${YELLOW}Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi

AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
echo -e "${GREEN}✓ Connected to AWS Account: $AWS_ACCOUNT${NC}"
echo -e "${GREEN}✓ Region: $AWS_REGION${NC}"
echo ""

# Build Lambda deployment package with dependencies
echo -e "${YELLOW}Building Lambda deployment package...${NC}"
bash "$SCRIPT_DIR/build-lambda.sh"
echo -e "${GREEN}✓ Lambda package built${NC}"
echo ""

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init
echo -e "${GREEN}✓ Terraform initialized${NC}"
echo ""

# Validate Terraform configuration
echo -e "${YELLOW}Validating Terraform configuration...${NC}"
terraform validate
echo -e "${GREEN}✓ Configuration valid${NC}"
echo ""

# Plan deployment
echo -e "${YELLOW}Planning deployment...${NC}"
echo ""
terraform plan -out=tfplan
echo ""

# Confirm deployment
echo -e "${YELLOW}Ready to deploy. This will create:${NC}"
echo "  - DynamoDB table for metrics storage"
echo "  - Lambda function for PageSpeed data collection"
echo "  - Lambda function for API"
echo "  - API Gateway HTTP API"
echo "  - EventBridge rule for weekly triggers"
echo "  - IAM roles and policies"
echo ""
read -p "Do you want to proceed? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled"
    exit 0
fi

# Apply Terraform
echo ""
echo -e "${YELLOW}Deploying infrastructure...${NC}"
terraform apply tfplan
echo ""

# Clean up plan file
rm -f tfplan

# Get outputs
echo ""
echo -e "${GREEN}=================================="
echo "Deployment Complete!"
echo -e "==================================${NC}"
echo ""

API_URL=$(terraform output -raw api_gateway_url)
COLLECTOR_FUNCTION=$(terraform output -raw collector_lambda_name)

echo "API Gateway Endpoints:"
echo "  All metrics: ${API_URL}/metrics"
echo "  Latest:      ${API_URL}/metrics/latest"
echo "  Summary:     ${API_URL}/metrics/summary"
echo ""
echo "To manually trigger data collection:"
echo "  aws lambda invoke --function-name $COLLECTOR_FUNCTION --region $AWS_REGION /tmp/response.json && cat /tmp/response.json"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Update your Hugo site to use the API endpoint above"
echo "2. Test the collector Lambda function manually (command above)"
echo "3. Wait for the weekly EventBridge trigger, or run it manually"
echo ""
echo "To view logs:"
echo "  aws logs tail /aws/lambda/$COLLECTOR_FUNCTION --follow"
echo ""

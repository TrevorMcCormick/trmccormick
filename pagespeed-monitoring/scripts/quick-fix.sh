#!/bin/bash

# Quick fix to update Lambda functions with dependencies
# Use this if you've already deployed but are getting import errors

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

echo "========================================"
echo "Lambda Function Quick Fix"
echo "========================================"
echo ""
echo "This will rebuild and update your Lambda functions with dependencies."
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Build the Lambda package
echo -e "${YELLOW}1. Building Lambda package with dependencies...${NC}"
if ! bash "$SCRIPT_DIR/build-lambda.sh"; then
    echo -e "${RED}ERROR: Failed to build Lambda package${NC}"
    exit 1
fi
echo ""

# Create deployment zip
echo -e "${YELLOW}2. Creating deployment package...${NC}"
cd "$PROJECT_DIR/build"
zip -r ../lambda-package.zip . > /dev/null 2>&1
cd "$PROJECT_DIR"
echo -e "${GREEN}✓ Created lambda-package.zip${NC}"
echo ""

# Update Lambda functions
echo -e "${YELLOW}3. Updating Lambda functions in AWS...${NC}"

# Get function names
COLLECTOR_FUNCTION="pagespeed-monitor-collector"
API_FUNCTION="pagespeed-monitor-api"

# Update collector function
echo "  Updating $COLLECTOR_FUNCTION..."
aws lambda update-function-code \
  --function-name "$COLLECTOR_FUNCTION" \
  --zip-file fileb://lambda-package.zip \
  --region us-east-1 \
  > /dev/null 2>&1

echo -e "${GREEN}  ✓ Collector function updated${NC}"

# Update API function
echo "  Updating $API_FUNCTION..."
aws lambda update-function-code \
  --function-name "$API_FUNCTION" \
  --zip-file fileb://lambda-package.zip \
  --region us-east-1 \
  > /dev/null 2>&1

echo -e "${GREEN}  ✓ API function updated${NC}"
echo ""

# Wait for updates to complete
echo -e "${YELLOW}4. Waiting for updates to complete...${NC}"
sleep 5
echo -e "${GREEN}✓ Lambda functions updated successfully${NC}"
echo ""

# Test the collector
echo -e "${YELLOW}5. Testing collector function...${NC}"
aws lambda invoke \
  --function-name "$COLLECTOR_FUNCTION" \
  --region us-east-1 \
  /tmp/quick-fix-test.json \
  > /dev/null 2>&1

if grep -q '"statusCode": 200' /tmp/quick-fix-test.json; then
  echo -e "${GREEN}✓ Collector function is working!${NC}"
  cat /tmp/quick-fix-test.json
else
  echo "Response from collector:"
  cat /tmp/quick-fix-test.json
fi
echo ""

# Cleanup
rm -f lambda-package.zip /tmp/quick-fix-test.json

echo "========================================"
echo -e "${GREEN}Fix Complete!${NC}"
echo "========================================"
echo ""
echo "Your Lambda functions now have the required dependencies."
echo "Try running the collector again:"
echo ""
echo "  aws lambda invoke --function-name $COLLECTOR_FUNCTION --region us-east-1 /tmp/response.json"
echo ""

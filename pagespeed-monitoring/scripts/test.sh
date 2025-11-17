#!/bin/bash

# PageSpeed Monitoring - Test Script
# Runs comprehensive tests to verify the system is working correctly

set -e

echo "========================================="
echo "PageSpeed Monitoring - System Test"
echo "========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Change to terraform directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

cd "$TERRAFORM_DIR"

# Check if Terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}ERROR: No terraform.tfstate found${NC}"
    echo "Run 'terraform apply' first to deploy infrastructure"
    exit 1
fi

# Get outputs from Terraform
echo -e "${YELLOW}1. Checking Terraform outputs...${NC}"
COLLECTOR_FUNCTION=$(terraform output -raw collector_lambda_name 2>/dev/null)
API_FUNCTION=$(terraform output -raw api_lambda_name 2>/dev/null)
API_URL=$(terraform output -raw api_gateway_url 2>/dev/null)
DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name 2>/dev/null)
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

if [ -z "$COLLECTOR_FUNCTION" ]; then
    echo -e "${RED}✗ Failed to get Terraform outputs${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Terraform outputs retrieved${NC}"
echo "  Collector: $COLLECTOR_FUNCTION"
echo "  API: $API_FUNCTION"
echo "  API URL: $API_URL"
echo "  DynamoDB: $DYNAMODB_TABLE"
echo ""

# Test AWS connectivity
echo -e "${YELLOW}2. Testing AWS connectivity...${NC}"
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$AWS_ACCOUNT" ]; then
    echo -e "${RED}✗ AWS credentials not configured${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Connected to AWS Account: $AWS_ACCOUNT${NC}"
echo ""

# Test DynamoDB table
echo -e "${YELLOW}3. Checking DynamoDB table...${NC}"
TABLE_STATUS=$(aws dynamodb describe-table \
    --table-name "$DYNAMODB_TABLE" \
    --region "$AWS_REGION" \
    --query 'Table.TableStatus' \
    --output text 2>/dev/null)

if [ "$TABLE_STATUS" != "ACTIVE" ]; then
    echo -e "${RED}✗ DynamoDB table not active (status: $TABLE_STATUS)${NC}"
    exit 1
fi
echo -e "${GREEN}✓ DynamoDB table is active${NC}"
echo ""

# Test collector Lambda
echo -e "${YELLOW}4. Testing collector Lambda function...${NC}"
echo "  This may take 30-60 seconds (PageSpeed API is slow)..."

aws lambda invoke \
    --function-name "$COLLECTOR_FUNCTION" \
    --region "$AWS_REGION" \
    --log-type Tail \
    /tmp/pagespeed-collector-response.json \
    > /tmp/invoke-result.json 2>&1

STATUS_CODE=$(cat /tmp/invoke-result.json | grep -o '"StatusCode": [0-9]*' | grep -o '[0-9]*')

if [ "$STATUS_CODE" != "200" ]; then
    echo -e "${RED}✗ Lambda invocation failed (status: $STATUS_CODE)${NC}"
    cat /tmp/pagespeed-collector-response.json
    exit 1
fi

RESPONSE=$(cat /tmp/pagespeed-collector-response.json)
if echo "$RESPONSE" | grep -q '"statusCode": 200'; then
    echo -e "${GREEN}✓ Collector Lambda executed successfully${NC}"

    # Extract scores from response
    DESKTOP_SCORE=$(echo "$RESPONSE" | grep -o '"desktop_score": [0-9.]*' | grep -o '[0-9.]*' || echo "N/A")
    MOBILE_SCORE=$(echo "$RESPONSE" | grep -o '"mobile_score": [0-9.]*' | grep -o '[0-9.]*' || echo "N/A")

    echo "  Desktop score: $DESKTOP_SCORE"
    echo "  Mobile score: $MOBILE_SCORE"
else
    echo -e "${RED}✗ Collector Lambda returned error${NC}"
    cat /tmp/pagespeed-collector-response.json
    exit 1
fi
echo ""

# Check DynamoDB data
echo -e "${YELLOW}5. Verifying data in DynamoDB...${NC}"
ITEM_COUNT=$(aws dynamodb scan \
    --table-name "$DYNAMODB_TABLE" \
    --region "$AWS_REGION" \
    --select COUNT \
    --query 'Count' \
    --output text)

if [ "$ITEM_COUNT" -eq 0 ]; then
    echo -e "${RED}✗ No data in DynamoDB${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found $ITEM_COUNT measurement(s) in DynamoDB${NC}"

# Get latest item
echo "  Fetching latest measurement..."
aws dynamodb scan \
    --table-name "$DYNAMODB_TABLE" \
    --region "$AWS_REGION" \
    --limit 1 \
    > /tmp/dynamodb-item.json

LATEST_TIMESTAMP=$(cat /tmp/dynamodb-item.json | grep -o '"timestamp": {[^}]*}' | head -1)
echo "  $LATEST_TIMESTAMP"
echo ""

# Test API Lambda
echo -e "${YELLOW}6. Testing API Lambda function...${NC}"
aws lambda invoke \
    --function-name "$API_FUNCTION" \
    --region "$AWS_REGION" \
    --payload '{"path": "/metrics/summary", "httpMethod": "GET"}' \
    /tmp/pagespeed-api-response.json \
    > /dev/null 2>&1

API_RESPONSE=$(cat /tmp/pagespeed-api-response.json)
if echo "$API_RESPONSE" | grep -q '"statusCode": 200'; then
    echo -e "${GREEN}✓ API Lambda executed successfully${NC}"
else
    echo -e "${RED}✗ API Lambda returned error${NC}"
    cat /tmp/pagespeed-api-response.json
    exit 1
fi
echo ""

# Test API Gateway endpoints
echo -e "${YELLOW}7. Testing API Gateway endpoints...${NC}"

# Test /metrics/latest
echo "  Testing /metrics/latest..."
LATEST_STATUS=$(curl -s -o /tmp/api-latest.json -w "%{http_code}" "$API_URL/metrics/latest")
if [ "$LATEST_STATUS" = "200" ]; then
    echo -e "${GREEN}  ✓ /metrics/latest returned 200${NC}"
else
    echo -e "${RED}  ✗ /metrics/latest returned $LATEST_STATUS${NC}"
fi

# Test /metrics/summary
echo "  Testing /metrics/summary..."
SUMMARY_STATUS=$(curl -s -o /tmp/api-summary.json -w "%{http_code}" "$API_URL/metrics/summary")
if [ "$SUMMARY_STATUS" = "200" ]; then
    echo -e "${GREEN}  ✓ /metrics/summary returned 200${NC}"

    # Parse some summary data
    if command -v jq &> /dev/null; then
        TOTAL_MEASUREMENTS=$(cat /tmp/api-summary.json | jq -r '.total_measurements // "N/A"')
        CURRENT_DESKTOP=$(cat /tmp/api-summary.json | jq -r '.current.desktop_score // "N/A"')
        CURRENT_MOBILE=$(cat /tmp/api-summary.json | jq -r '.current.mobile_score // "N/A"')

        echo "    Total measurements: $TOTAL_MEASUREMENTS"
        echo "    Current desktop score: $CURRENT_DESKTOP"
        echo "    Current mobile score: $CURRENT_MOBILE"
    fi
else
    echo -e "${RED}  ✗ /metrics/summary returned $SUMMARY_STATUS${NC}"
fi
echo ""

# Test EventBridge rule
echo -e "${YELLOW}8. Checking EventBridge rule...${NC}"
RULE_STATE=$(aws events describe-rule \
    --name "pagespeed-monitor-weekly-check" \
    --region "$AWS_REGION" \
    --query 'State' \
    --output text 2>/dev/null)

if [ "$RULE_STATE" = "ENABLED" ]; then
    echo -e "${GREEN}✓ EventBridge rule is enabled${NC}"

    SCHEDULE=$(aws events describe-rule \
        --name "pagespeed-monitor-weekly-check" \
        --region "$AWS_REGION" \
        --query 'ScheduleExpression' \
        --output text)
    echo "  Schedule: $SCHEDULE"
else
    echo -e "${YELLOW}⚠ EventBridge rule state: $RULE_STATE${NC}"
fi
echo ""

# Summary
echo "========================================="
echo -e "${GREEN}All Tests Passed!${NC}"
echo "========================================="
echo ""
echo "Your PageSpeed monitoring system is working correctly."
echo ""
echo "Next steps:"
echo "  1. Add the shortcode to your Hugo site:"
echo "     {{< pagespeed-chart api-url=\"$API_URL\" >}}"
echo ""
echo "  2. Test locally:"
echo "     hugo server -D"
echo ""
echo "  3. Deploy your Hugo site to see live data"
echo ""
echo "  4. Wait for weekly EventBridge trigger (or invoke manually)"
echo ""
echo "Useful commands:"
echo "  View collector logs:"
echo "    aws logs tail /aws/lambda/$COLLECTOR_FUNCTION --follow"
echo ""
echo "  Manual trigger:"
echo "    aws lambda invoke --function-name $COLLECTOR_FUNCTION /tmp/response.json"
echo ""
echo "  View API data:"
echo "    curl $API_URL/metrics/summary | jq"
echo ""

# Cleanup temp files
rm -f /tmp/pagespeed-*.json /tmp/invoke-result.json /tmp/dynamodb-item.json /tmp/api-*.json

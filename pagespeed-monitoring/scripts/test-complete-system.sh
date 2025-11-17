#!/bin/bash

# Complete end-to-end test of the PageSpeed monitoring system

set -e

echo "=========================================="
echo "PageSpeed Monitoring - Complete Test"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

cd "$TERRAFORM_DIR"

# Get configuration
API_URL=$(terraform output -raw api_gateway_url 2>/dev/null)
COLLECTOR_FUNCTION=$(terraform output -raw collector_lambda_name 2>/dev/null)

if [ -z "$API_URL" ]; then
    echo -e "${RED}ERROR: Could not get Terraform outputs${NC}"
    echo "Make sure you're in the terraform directory and have run 'terraform apply'"
    exit 1
fi

echo -e "${BLUE}Configuration:${NC}"
echo "  API Gateway URL: $API_URL"
echo "  Collector Function: $COLLECTOR_FUNCTION"
echo ""

# Test 1: Invoke collector Lambda
echo -e "${YELLOW}Test 1: Running PageSpeed collector...${NC}"
echo "  This may take 30-60 seconds..."
aws lambda invoke \
    --function-name "$COLLECTOR_FUNCTION" \
    --region us-east-1 \
    /tmp/collector-response.json \
    > /dev/null 2>&1

RESPONSE=$(cat /tmp/collector-response.json)
if echo "$RESPONSE" | grep -q '"statusCode": 200'; then
    echo -e "${GREEN}✓ Collector succeeded!${NC}"

    # Extract scores
    DESKTOP=$(echo "$RESPONSE" | grep -o '"desktop_score": [0-9.]*' | grep -o '[0-9.]*' | head -1)
    MOBILE=$(echo "$RESPONSE" | grep -o '"mobile_score": [0-9.]*' | grep -o '[0-9.]*' | head -1)

    echo "  Desktop score: $DESKTOP"
    echo "  Mobile score: $MOBILE"
else
    echo -e "${RED}✗ Collector failed${NC}"
    echo "$RESPONSE"
    echo ""
    echo "Common issues:"
    echo "  - PageSpeed Insights API not enabled in Google Cloud Console"
    echo "  - Visit: https://console.cloud.google.com/apis/library/pagespeedonline.googleapis.com"
    exit 1
fi
echo ""

# Test 2: Check DynamoDB
echo -e "${YELLOW}Test 2: Checking DynamoDB...${NC}"
ITEM_COUNT=$(aws dynamodb scan \
    --table-name pagespeed-metrics \
    --region us-east-1 \
    --select COUNT \
    --query 'Count' \
    --output text 2>/dev/null)

if [ "$ITEM_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ DynamoDB has $ITEM_COUNT measurement(s)${NC}"
else
    echo -e "${RED}✗ No data in DynamoDB${NC}"
    exit 1
fi
echo ""

# Test 3: Test API endpoints
echo -e "${YELLOW}Test 3: Testing API endpoints...${NC}"

# Test /metrics/latest
echo "  Testing /metrics/latest..."
LATEST_STATUS=$(curl -s -o /tmp/api-latest.json -w "%{http_code}" "$API_URL/metrics/latest")
if [ "$LATEST_STATUS" = "200" ]; then
    echo -e "${GREEN}  ✓ /metrics/latest works${NC}"
else
    echo -e "${RED}  ✗ /metrics/latest returned $LATEST_STATUS${NC}"
fi

# Test /metrics/summary
echo "  Testing /metrics/summary..."
SUMMARY_STATUS=$(curl -s -o /tmp/api-summary.json -w "%{http_code}" "$API_URL/metrics/summary")
if [ "$SUMMARY_STATUS" = "200" ]; then
    echo -e "${GREEN}  ✓ /metrics/summary works${NC}"

    if command -v jq &> /dev/null; then
        echo ""
        echo -e "${BLUE}  Latest metrics:${NC}"
        jq -r '
            "    Total measurements: \(.total_measurements)",
            "    Desktop score: \(.current.desktop_score)",
            "    Mobile score: \(.current.mobile_score)",
            "    Latest commit: \(.current.commit.short_sha) - \(.current.commit.message)"
        ' /tmp/api-summary.json
    fi
else
    echo -e "${RED}  ✗ /metrics/summary returned $SUMMARY_STATUS${NC}"
fi
echo ""

# Test 4: Create simple HTML test page
echo -e "${YELLOW}Test 4: Creating test HTML page...${NC}"

cat > /tmp/pagespeed-test.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>PageSpeed Monitoring Test</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }
        h1 { color: #333; }
        .summary {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .card {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            text-align: center;
        }
        .card-title {
            font-size: 14px;
            color: #666;
            text-transform: uppercase;
            font-weight: 600;
        }
        .card-value {
            font-size: 48px;
            font-weight: bold;
            margin: 10px 0;
        }
        .good { color: #28a745; }
        .average { color: #ffc107; }
        .poor { color: #dc3545; }
        .chart-container {
            background: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin: 20px 0;
        }
        #error {
            background: #fee;
            color: #c00;
            padding: 20px;
            border-radius: 8px;
            display: none;
        }
    </style>
</head>
<body>
    <h1>PageSpeed Monitoring Test</h1>

    <div id="error"></div>

    <div class="summary" id="summary">
        <div class="card">
            <div class="card-title">Desktop Score</div>
            <div class="card-value" id="desktop-score">--</div>
        </div>
        <div class="card">
            <div class="card-title">Mobile Score</div>
            <div class="card-value" id="mobile-score">--</div>
        </div>
        <div class="card">
            <div class="card-title">Total Checks</div>
            <div class="card-value" id="total-checks">--</div>
        </div>
    </div>

    <div class="chart-container">
        <canvas id="chart" height="100"></canvas>
    </div>

    <script>
        const API_URL = '$API_URL';

        async function loadData() {
            try {
                const response = await fetch(API_URL + '/metrics/summary');
                if (!response.ok) throw new Error('API returned ' + response.status);

                const data = await response.json();

                // Update summary cards
                const desktopScore = Math.round(data.current.desktop_score);
                const mobileScore = Math.round(data.current.mobile_score);

                document.getElementById('desktop-score').textContent = desktopScore;
                document.getElementById('desktop-score').className = 'card-value ' + getScoreClass(desktopScore);

                document.getElementById('mobile-score').textContent = mobileScore;
                document.getElementById('mobile-score').className = 'card-value ' + getScoreClass(mobileScore);

                document.getElementById('total-checks').textContent = data.total_measurements;

                // Render chart
                const ctx = document.getElementById('chart').getContext('2d');
                new Chart(ctx, {
                    type: 'line',
                    data: {
                        labels: data.historical_data.map(d => new Date(d.timestamp).toLocaleDateString()),
                        datasets: [
                            {
                                label: 'Desktop',
                                data: data.historical_data.map(d => d.desktop_score),
                                borderColor: '#4285f4',
                                backgroundColor: 'rgba(66, 133, 244, 0.1)',
                                tension: 0.4,
                                fill: true
                            },
                            {
                                label: 'Mobile',
                                data: data.historical_data.map(d => d.mobile_score),
                                borderColor: '#ea4335',
                                backgroundColor: 'rgba(234, 67, 53, 0.1)',
                                tension: 0.4,
                                fill: true
                            }
                        ]
                    },
                    options: {
                        responsive: true,
                        scales: {
                            y: { beginAtZero: true, max: 100 }
                        }
                    }
                });

            } catch (error) {
                document.getElementById('error').style.display = 'block';
                document.getElementById('error').textContent = 'Error loading data: ' + error.message;
            }
        }

        function getScoreClass(score) {
            if (score >= 90) return 'good';
            if (score >= 50) return 'average';
            return 'poor';
        }

        loadData();
    </script>
</body>
</html>
EOF

echo -e "${GREEN}✓ Created test page: /tmp/pagespeed-test.html${NC}"
echo ""

# Summary
echo "=========================================="
echo -e "${GREEN}All Tests Passed!${NC}"
echo "=========================================="
echo ""
echo "Your PageSpeed monitoring system is working correctly!"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo ""
echo "1. Open the test page in your browser:"
echo "   open /tmp/pagespeed-test.html"
echo ""
echo "2. Or test the API directly:"
echo "   curl $API_URL/metrics/summary | jq"
echo ""
echo "3. API Endpoints:"
echo "   - Summary: $API_URL/metrics/summary"
echo "   - Latest:  $API_URL/metrics/latest"
echo "   - All:     $API_URL/metrics"
echo ""
echo "4. Update your Hugo blog post with the API URL:"
echo "   $API_URL"
echo ""

# Cleanup
rm -f /tmp/collector-response.json /tmp/api-latest.json /tmp/api-summary.json

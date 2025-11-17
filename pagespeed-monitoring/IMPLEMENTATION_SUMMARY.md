# PageSpeed Monitoring System - Implementation Summary

## What Was Built

A complete serverless PageSpeed monitoring system with the following components:

### AWS Infrastructure
- **DynamoDB table** for storing historical metrics
- **Lambda function** (collector) to query PageSpeed API and GitHub
- **Lambda function** (API) to serve data to your website
- **API Gateway** HTTP API with CORS configured
- **EventBridge rule** for weekly automatic checks
- **IAM roles** with least-privilege permissions
- **CloudWatch logs** for debugging

### Frontend Components
- **Hugo shortcode** for embedding visualization
- **Chart.js integration** for interactive charts
- **Summary cards** showing current scores and trends
- **Opportunities display** showing optimization suggestions
- **Click-to-GitHub** functionality on data points

### Infrastructure as Code
- **Terraform configuration** for reproducible deployments
- **Deployment scripts** for automated setup
- **Testing scripts** for verification

### Documentation
- **README.md** - Comprehensive documentation
- **QUICKSTART.md** - 15-minute setup guide
- **Blog post** - Full explanation and walkthrough
- **This summary** - Implementation overview

## Files Created

```
pagespeed-monitoring/
├── lambda/
│   ├── collector.py              # PageSpeed data collection Lambda
│   ├── api.py                    # API Gateway Lambda
│   └── requirements.txt          # Python dependencies
│
├── terraform/
│   ├── main.tf                   # Main infrastructure (DynamoDB, Lambda, API Gateway, EventBridge)
│   ├── variables.tf              # Configuration variables
│   ├── outputs.tf                # Output values (API URL, function names)
│   └── terraform.tfvars.example  # Example configuration
│
├── scripts/
│   ├── deploy.sh                 # Automated deployment script
│   └── test.sh                   # System verification script
│
├── .gitignore                    # Prevent committing secrets
├── README.md                     # Full documentation
├── QUICKSTART.md                 # Quick setup guide
└── IMPLEMENTATION_SUMMARY.md     # This file
```

```
# Hugo site files
layouts/
└── shortcodes/
    └── pagespeed-chart.html      # Visualization component

content/
└── posts/
    └── pagespeed-monitoring/
        └── index.md              # Blog post explaining the system
```

## Architecture Overview

```
Weekly Trigger (EventBridge)
        ↓
Collector Lambda
        ↓
    [Queries]
        ↓
PageSpeed API + GitHub API
        ↓
    [Stores]
        ↓
    DynamoDB
        ↓
    [Serves]
        ↓
    API Lambda ← API Gateway
        ↓
    [Fetches]
        ↓
Hugo Shortcode (Chart.js)
        ↓
    Your Website
```

## What It Does

1. **Every Monday at noon UTC**, EventBridge triggers the collector Lambda

2. **Collector Lambda**:
   - Queries PageSpeed Insights API for desktop and mobile scores
   - Fetches the latest Git commit from GitHub
   - Extracts performance metrics:
     - Performance score (0-100)
     - Core Web Vitals (LCP, FID, CLS)
     - Timing metrics (FCP, TTI, TBT)
     - Optimization opportunities
     - Diagnostics
   - Stores everything in DynamoDB with commit correlation

3. **API Lambda** serves three endpoints:
   - `/metrics` - All historical data
   - `/metrics/latest` - Most recent measurement
   - `/metrics/summary` - Statistics, trends, top opportunities

4. **Hugo shortcode** on your website:
   - Fetches data from API Gateway
   - Renders summary cards (current scores, trends)
   - Displays interactive Chart.js visualization
   - Shows top optimization opportunities
   - Enables click-to-GitHub on data points

## Data Structure

### DynamoDB Item
```json
{
  "timestamp": "2025-11-17T12:00:00.000Z",
  "url": "https://trmccormick.com",
  "desktop": {
    "performance_score": 98,
    "fcp": 456,
    "lcp": 892,
    "tbt": 23,
    "cls": 0.01,
    "opportunities": [...],
    "diagnostics": [...]
  },
  "mobile": {
    "performance_score": 92,
    ...
  },
  "commit": {
    "sha": "a3b2c1d4e5f6",
    "short_sha": "a3b2c1d",
    "message": "Optimize images",
    "author": "Trevor McCormick",
    "url": "https://github.com/..."
  },
  "desktop_score": 98,
  "mobile_score": 92,
  "average_score": 95
}
```

## Cost Analysis

### Monthly Costs (Estimated)
- DynamoDB: $0.25 (4 writes, ~500 reads)
- Lambda (collector): $0.01 (4 invocations @ 30s)
- Lambda (API): $0.01 (~500 invocations @ 100ms)
- API Gateway: $0.10 (~500 requests)
- CloudWatch Logs: $0.05
- **Total: ~$0.42/month**

### Free Services Used
- PageSpeed Insights API (25,000/day limit)
- GitHub API (public repos)

## Next Steps for You

### 1. Get API Key
Visit https://console.cloud.google.com/apis/credentials
- Create/select a project
- Enable "PageSpeed Insights API"
- Create API key

### 2. Configure Terraform
```bash
cd pagespeed-monitoring/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

Required values:
```hcl
target_website_url = "https://trmccormick.com"
github_repo        = "YOUR_USERNAME/trmccormick"
pagespeed_api_key  = "YOUR_API_KEY"
```

### 3. Deploy
```bash
cd pagespeed-monitoring
./scripts/deploy.sh
```

Or manually:
```bash
cd terraform
terraform init
terraform apply
```

### 4. Test
```bash
cd pagespeed-monitoring
./scripts/test.sh
```

This verifies:
- Terraform deployed successfully
- Lambda functions work
- DynamoDB has data
- API endpoints return data
- EventBridge rule is enabled

### 5. Add to Blog Post

Update the blog post with your API URL:

In `content/posts/pagespeed-monitoring/index.md`, find:
```markdown
{{< pagespeed-chart api-url="YOUR_API_GATEWAY_URL_HERE" >}}
```

Replace with your actual API Gateway URL from Terraform output.

### 6. Deploy Hugo Site

```bash
hugo --minify
# Deploy to S3/CloudFront as you normally do
```

### 7. Verify Live

Visit your blog post URL and verify:
- Summary cards show current scores
- Chart displays with data points
- Opportunities list shows suggestions
- Clicking data points opens GitHub commits

## Customization Options

### Change Schedule
Edit `terraform/variables.tf`:
```hcl
schedule_expression = "cron(0 12 ? * MON *)"  # Weekly
# Change to:
# Daily: "cron(0 12 * * ? *)"
# Monthly: "cron(0 12 1 * ? *)"
```

### Add Alerting
Modify `lambda/collector.py` to add SNS notifications:
```python
if current_score < previous_score - 10:
    sns.publish(
        TopicArn='arn:aws:sns:...',
        Subject='PageSpeed Alert',
        Message=f'Score dropped {drop} points'
    )
```

### Test Multiple Pages
Add a list of URLs to test:
```python
urls = [
    'https://trmccormick.com',
    'https://trmccormick.com/posts/simple-infrastructure',
    'https://trmccormick.com/about'
]
```

### CI/CD Integration
Add to GitHub Actions:
```yaml
- name: Check PageSpeed
  run: |
    aws lambda invoke \
      --function-name pagespeed-monitor-collector \
      response.json
```

## Monitoring Commands

### View Logs
```bash
# Collector logs
aws logs tail /aws/lambda/pagespeed-monitor-collector --follow

# API logs
aws logs tail /aws/lambda/pagespeed-monitor-api --follow
```

### Manual Trigger
```bash
aws lambda invoke \
  --function-name pagespeed-monitor-collector \
  --region us-east-1 \
  /tmp/response.json

cat /tmp/response.json
```

### Check DynamoDB
```bash
# Count items
aws dynamodb scan \
  --table-name pagespeed-metrics \
  --select COUNT

# Get latest item
aws dynamodb scan \
  --table-name pagespeed-metrics \
  --limit 1
```

### Test API
```bash
API_URL="https://your-api-gateway-url"

# Get summary
curl $API_URL/metrics/summary | jq

# Get latest
curl $API_URL/metrics/latest | jq

# Get all metrics
curl $API_URL/metrics | jq
```

## Troubleshooting

### No data in chart
1. Check if collector ran: `aws lambda get-function --function-name pagespeed-monitor-collector`
2. Manually invoke: `aws lambda invoke --function-name pagespeed-monitor-collector /tmp/response.json`
3. Check DynamoDB: `aws dynamodb scan --table-name pagespeed-metrics --limit 1`
4. Verify API URL in shortcode

### Lambda timeout
- Increase timeout in `terraform/main.tf` (collector Lambda)
- Current: 60 seconds, increase to 90 if needed

### CORS errors
- Update `cors_allowed_origins` in `terraform/variables.tf`
- Add your domain(s)
- Run `terraform apply`

### API 500 errors
- Check Lambda logs
- Verify DynamoDB permissions
- Test Lambda directly: `aws lambda invoke --function-name pagespeed-monitor-api --payload '{"path":"/metrics/latest"}' /tmp/test.json`

## Security Considerations

✅ **What's Secure:**
- Secrets not in Git (`.gitignore` includes `terraform.tfvars`)
- Least-privilege IAM roles
- DynamoDB encryption at rest
- Point-in-time recovery enabled
- HTTPS only (API Gateway, website)

⚠️ **Production Recommendations:**
- Store API keys in AWS Secrets Manager
- Add API Gateway authentication (API key or Cognito)
- Restrict CORS to specific domains (not wildcard)
- Enable CloudFront in front of API Gateway
- Set up CloudWatch alarms for errors

## Cleanup

To remove everything:
```bash
cd pagespeed-monitoring/terraform
terraform destroy
```

This deletes all AWS resources and data permanently.

## Support

- **Documentation**: See `README.md` and `QUICKSTART.md`
- **Logs**: `aws logs tail /aws/lambda/FUNCTION_NAME --follow`
- **API Test**: `curl https://your-api-url/metrics/summary | jq`
- **Terraform Debug**: `terraform plan` to see changes before applying

## What's Next?

Ideas for extending the system:
1. Add Slack notifications on score drops
2. Test multiple pages across the site
3. Integrate with CI/CD for pre-deployment checks
4. Add custom business metrics beyond PageSpeed
5. Create comparison views (week-over-week, month-over-month)
6. Build automated image optimization triggers
7. Track infrastructure costs alongside performance

---

## Summary

You now have a complete, production-ready PageSpeed monitoring system that:
- ✅ Automatically checks performance weekly
- ✅ Stores historical data with Git correlation
- ✅ Provides a public API for the data
- ✅ Visualizes results on your website
- ✅ Costs less than $0.50/month
- ✅ Requires zero ongoing maintenance
- ✅ Is fully reproducible via Terraform
- ✅ Includes comprehensive documentation

**Estimated setup time**: 15 minutes
**Monthly cost**: ~$0.40
**Maintenance required**: None

Enjoy your self-monitoring website!

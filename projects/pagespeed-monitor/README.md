# PageSpeed Monitor with GitHub Webhooks

Automated performance monitoring triggered by GitHub push events. Every time you push to your main branch, this system automatically measures your site's PageSpeed Insights scores and stores them with commit metadata.

## Architecture

**Event-Driven Collection:**
1. GitHub fires webhook on push to main
2. API Gateway validates webhook signature
3. Webhook handler Lambda extracts commit SHA
4. Collector Lambda queries PageSpeed Insights
5. Metrics + commit data stored in DynamoDB

**On-Demand Visualization:**
- Frontend fetches data via API Gateway
- API Lambda aggregates metrics from DynamoDB
- Chart.js renders performance timeline

## Prerequisites

- AWS Account with CLI configured
- Terraform >= 1.0
- GitHub repository with admin access
- (Optional) Google PageSpeed Insights API key

## Setup Instructions

### 1. Generate Webhook Secret

```bash
openssl rand -hex 32
```

Save this value - you'll need it for both Terraform and GitHub webhook configuration.

### 2. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:
- `github_webhook_secret`: The token you just generated
- `target_url`: Your website URL
- `pagespeed_api_key`: (Optional) Your Google API key

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy
terraform apply
```

**Note the outputs:**
- `webhook_url`: You'll configure this in GitHub
- `metrics_api_url`: Your frontend will fetch from this

### 4. Configure GitHub Webhook

1. Go to your GitHub repository
2. Settings → Webhooks → Add webhook
3. Configure:
   - **Payload URL**: The `webhook_url` from Terraform output
   - **Content type**: `application/json`
   - **Secret**: Your `github_webhook_secret` value
   - **Which events**: Select "Just the push event"
   - **Active**: ✅ Checked

4. Click "Add webhook"

### 5. Test the Webhook

Make a test commit and push:

```bash
git commit --allow-empty -m "Test PageSpeed webhook"
git push origin main
```

**Verify it worked:**

1. In GitHub: Settings → Webhooks → Click your webhook → "Recent Deliveries"
   - Should show Status 202 (Accepted)

2. In AWS CloudWatch Logs:
   - `/aws/lambda/pagespeed-monitor-webhook`: Should show webhook received
   - `/aws/lambda/pagespeed-monitor-collector`: Should show metrics collection

3. In DynamoDB:
   - Open the `pagespeed-monitor-metrics` table
   - Should see a new item with your commit SHA

4. Test API endpoint:
   ```bash
   curl https://YOUR-API-ENDPOINT/prod/metrics
   ```

## Frontend Integration

Update your blog/dashboard to fetch from the new API:

```javascript
fetch('https://YOUR-API-ENDPOINT/prod/metrics')
  .then(res => res.json())
  .then(data => {
    console.log(`Found ${data.count} measurements`);
    // Render with Chart.js
    data.metrics.forEach(metric => {
      console.log(`${metric.commit.sha}: Mobile ${metric.mobile.score}`);
    });
  });
```

## Cost Estimate

**Per commit pushed to main:**
- API Gateway: $0.000001 (1 request)
- Lambda Webhook Handler: ~$0.000001 (128MB, <100ms)
- Lambda Collector: ~$0.00002 (256MB, ~10s)
- DynamoDB: ~$0.00000125 (1 write)
- **Total per commit: ~$0.00003** (3 cents per 1000 commits)

**Monthly reading (assuming 200 page loads):**
- API Gateway: ~$0.0002
- Lambda API Handler: ~$0.0001
- DynamoDB reads: ~$0.00025
- **Total reads: ~$0.00055/month**

**Total monthly cost (20 commits + 200 reads): ~$0.001**

Plus DynamoDB storage: ~$0.25/GB/month (negligible for this use case)

## Monitoring

### Check Recent Deployments

```bash
# View DynamoDB items
aws dynamodb scan --table-name pagespeed-monitor-metrics \
  --query 'Items[*].[commit.sha, mobile.score, desktop.score]' \
  --output table
```

### View Lambda Logs

```bash
# Webhook handler logs
aws logs tail /aws/lambda/pagespeed-monitor-webhook --follow

# Collector logs
aws logs tail /aws/lambda/pagespeed-monitor-collector --follow
```

### Test Webhook Manually

```bash
# Get your webhook secret from terraform.tfvars
SECRET="your-secret-here"

# Create test payload
PAYLOAD='{"ref":"refs/heads/main","head_commit":{"id":"abc123","message":"Test","author":{"name":"Test"},"timestamp":"2025-01-01T00:00:00Z"}}'

# Generate signature
SIGNATURE=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$SECRET" | sed 's/SHA2-256(stdin)= //')

# Send webhook
curl -X POST YOUR_WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -H "X-Hub-Signature-256: sha256=$SIGNATURE" \
  -H "X-GitHub-Event: push" \
  -d "$PAYLOAD"
```

## Troubleshooting

**Webhook returns 403:**
- Check that your webhook secret matches in both GitHub and Terraform

**Webhook returns 500:**
- Check CloudWatch logs for webhook Lambda
- Verify IAM permissions

**No metrics appearing:**
- Verify collector Lambda has internet access
- Check PageSpeed Insights API rate limits (default: 400/min without API key)
- Confirm DynamoDB table name in environment variables

**API returns empty results:**
- Check DynamoDB table has items
- Verify API Lambda has correct table name in environment

## Advanced Configuration

### Add PageSpeed Insights API Key

Get a key from [Google Cloud Console](https://console.cloud.google.com/apis/credentials):

1. Enable PageSpeed Insights API
2. Create API key
3. Add to `terraform.tfvars`: `pagespeed_api_key = "YOUR_KEY"`
4. Run `terraform apply`

**Benefits:**
- Higher rate limits (25,000 requests/day)
- More consistent quotas
- Better for frequent commits

### Deploy to Multiple Environments

```bash
# Create workspace
terraform workspace new staging
terraform workspace select staging

# Deploy with different config
terraform apply -var="environment=staging" -var="target_url=https://staging.trmccormick.com"
```

### Add Alerting

Monitor failed webhooks:

```bash
# Add to main.tf
resource "aws_cloudwatch_metric_alarm" "webhook_errors" {
  alarm_name          = "pagespeed-webhook-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5

  dimensions = {
    FunctionName = aws_lambda_function.webhook.function_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

## Cleanup

To remove all resources:

```bash
cd terraform
terraform destroy
```

This will delete:
- All Lambda functions
- API Gateway
- DynamoDB table (including all data!)
- CloudWatch log groups
- IAM roles and policies

## Next Steps

1. ✅ Deploy infrastructure
2. ✅ Configure GitHub webhook
3. ✅ Push a commit to test
4. Update your blog frontend to use the new API
5. (Optional) Add alerting for failed measurements
6. (Optional) Create dashboard showing trends over time

## Support

- Terraform issues: Check [AWS Provider docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- Lambda issues: Check CloudWatch logs
- GitHub webhook issues: Check webhook "Recent Deliveries" in GitHub settings

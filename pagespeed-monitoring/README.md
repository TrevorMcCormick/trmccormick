# PageSpeed Insights Monitoring System

A serverless AWS-based system that automatically monitors your website's PageSpeed Insights score, correlates performance metrics with Git commits, and visualizes the data on your Hugo site.

## Features

- 🔄 **Automated weekly checks** via EventBridge cron
- 📊 **Dual testing** for desktop and mobile performance
- 🔗 **Git correlation** linking each measurement to specific commits
- 💰 **Cost-effective** (~$0.50/month on AWS)
- 📈 **Live visualization** with Chart.js on your Hugo site
- 🎯 **Actionable insights** showing top optimization opportunities
- 🔒 **Infrastructure as Code** fully Terraform-managed

## Architecture

```
EventBridge → Lambda (Collector) → PageSpeed API
                  ↓
              DynamoDB
                  ↓
Lambda (API) → API Gateway → Your Website
```

## Prerequisites

- AWS Account with CLI configured
- Terraform >= 1.0
- Python 3.11
- Hugo website (for visualization)
- Google Cloud account (for PageSpeed API key)
- GitHub repository

## Quick Start

### 1. Get API Keys

**PageSpeed Insights API Key:**
1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Create a new project or select existing
3. Enable "PageSpeed Insights API"
4. Create credentials → API Key
5. Copy the API key

**GitHub Token (optional, only for private repos):**
1. Go to GitHub Settings → Developer Settings → Personal Access Tokens
2. Generate new token with `repo` scope
3. Copy the token

### 2. Configure Terraform

```bash
cd pagespeed-monitoring/terraform

# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

Update these values in `terraform.tfvars`:
```hcl
target_website_url = "https://your-website.com"
github_repo        = "yourusername/yourrepo"
pagespeed_api_key  = "your-pagespeed-api-key"
github_token       = "your-github-token"  # Optional
```

### 3. Deploy Infrastructure

```bash
cd pagespeed-monitoring/terraform

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy
terraform apply
```

After deployment, Terraform will output your API Gateway URL. Save this!

### 4. Test the Collector

Manually trigger the collector to populate initial data:

```bash
# Get the function name from Terraform output
aws lambda invoke \
  --function-name pagespeed-monitor-collector \
  --region us-east-1 \
  /tmp/response.json

cat /tmp/response.json
```

### 5. Add Visualization to Hugo Site

1. Copy the shortcode (already in your `layouts/shortcodes/` if deploying from this repo)
2. In your blog post markdown, add:

```markdown
{{< pagespeed-chart api-url="https://YOUR_API_GATEWAY_URL" >}}
```

Replace `YOUR_API_GATEWAY_URL` with the URL from Terraform output.

### 6. Test the Website

```bash
# Start Hugo dev server
hugo server -D

# Visit http://localhost:1313/your-post
# You should see the PageSpeed chart with data
```

## Project Structure

```
pagespeed-monitoring/
├── lambda/
│   ├── collector.py       # Lambda for PageSpeed data collection
│   ├── api.py            # Lambda for API Gateway
│   └── requirements.txt  # Python dependencies
├── terraform/
│   ├── main.tf           # Main infrastructure
│   ├── variables.tf      # Configuration variables
│   ├── outputs.tf        # Output values
│   └── terraform.tfvars.example
├── scripts/
│   └── deploy.sh         # Automated deployment script
└── README.md
```

## Configuration Options

### Schedule Expression

Change the EventBridge schedule in `terraform/variables.tf`:

```hcl
# Every Monday at noon UTC (default)
schedule_expression = "cron(0 12 ? * MON *)"

# Every day at 6 AM UTC
schedule_expression = "cron(0 6 * * ? *)"

# First day of every month at midnight UTC
schedule_expression = "cron(0 0 1 * ? *)"
```

### CORS Settings

Update allowed origins for API Gateway:

```hcl
cors_allowed_origins = [
  "https://your-website.com",
  "https://www.your-website.com",
  "http://localhost:1313"
]
```

### Visualization Options

The Hugo shortcode accepts parameters:

```markdown
{{< pagespeed-chart
    api-url="https://your-api-gateway-url"
    height="600"
    show-mobile="true"
>}}
```

Parameters:
- `api-url` (required): Your API Gateway endpoint
- `height` (optional): Chart height in pixels (default: 500)
- `show-mobile` (optional): Show mobile scores (default: true)

## API Endpoints

After deployment, three endpoints are available:

### Get All Metrics
```bash
GET https://your-api-gateway-url/metrics
```

Returns all historical measurements.

### Get Latest Measurement
```bash
GET https://your-api-gateway-url/metrics/latest
```

Returns only the most recent data.

### Get Summary Statistics
```bash
GET https://your-api-gateway-url/metrics/summary
```

Returns computed statistics, trends, and top opportunities. This is what the visualization uses.

## Monitoring and Debugging

### View Lambda Logs

```bash
# Collector logs
aws logs tail /aws/lambda/pagespeed-monitor-collector --follow

# API logs
aws logs tail /aws/lambda/pagespeed-monitor-api --follow
```

### Check DynamoDB Data

```bash
aws dynamodb scan \
  --table-name pagespeed-metrics \
  --region us-east-1
```

### Test API Endpoints

```bash
# Get summary
curl https://your-api-gateway-url/metrics/summary | jq

# Get latest
curl https://your-api-gateway-url/metrics/latest | jq
```

## Cost Breakdown

Based on weekly checks with ~1000 website visitors monthly:

| Service | Monthly Cost |
|---------|-------------|
| DynamoDB (on-demand) | $0.25 |
| Lambda (collector, 4 invocations) | $0.01 |
| Lambda (API, ~500 invocations) | $0.01 |
| API Gateway (~500 requests) | $0.10 |
| CloudWatch Logs | $0.05 |
| **Total** | **~$0.42/month** |

PageSpeed Insights API: Free (25,000 requests/day limit)
GitHub API: Free for public repos

## Troubleshooting

### "No data available" on website

**Check:**
1. Has the collector Lambda run at least once?
   ```bash
   aws lambda invoke --function-name pagespeed-monitor-collector /tmp/response.json
   ```
2. Is there data in DynamoDB?
   ```bash
   aws dynamodb scan --table-name pagespeed-metrics --limit 1
   ```
3. Is the API URL correct in the shortcode?
4. Check browser console for CORS errors

### Collector Lambda timing out

The PageSpeed API can be slow (30-60 seconds). The Lambda timeout is set to 60 seconds. If it's timing out:

1. Increase timeout in `terraform/main.tf`:
   ```hcl
   resource "aws_lambda_function" "collector" {
     timeout = 90  # Increase to 90 seconds
     ...
   }
   ```
2. Re-deploy: `terraform apply`

### API returning 500 errors

Check Lambda logs:
```bash
aws logs tail /aws/lambda/pagespeed-monitor-api --follow
```

Common issues:
- DynamoDB permissions (check IAM role)
- Malformed data in DynamoDB (check with `aws dynamodb scan`)

### EventBridge not triggering

Check EventBridge rule:
```bash
aws events describe-rule --name pagespeed-monitor-weekly-check
```

Verify Lambda has permission:
```bash
aws lambda get-policy --function-name pagespeed-monitor-collector
```

## Updating the System

### Update Lambda Code

After modifying Python code:

```bash
cd pagespeed-monitoring/terraform
terraform apply
```

Terraform will detect changes and update the Lambda functions.

### Update Infrastructure

Modify `terraform/*.tf` files and run:

```bash
terraform plan
terraform apply
```

## Cleanup

To remove all AWS resources:

```bash
cd pagespeed-monitoring/terraform
terraform destroy
```

This will delete:
- Lambda functions
- DynamoDB table (and all data!)
- API Gateway
- EventBridge rules
- IAM roles and policies
- CloudWatch log groups

## Security Best Practices

1. **Never commit secrets** to Git
   - Add `terraform.tfvars` to `.gitignore`
   - Use environment variables or AWS Secrets Manager for production

2. **Restrict API access**
   - Update CORS origins to only your domain
   - Consider adding API Gateway authentication for production

3. **Enable DynamoDB encryption**
   - Already enabled in the Terraform configuration
   - Point-in-time recovery is enabled

4. **Review IAM permissions**
   - Lambda roles use least-privilege access
   - Collector can only write to DynamoDB
   - API Lambda can only read from DynamoDB

## Future Enhancements

Ideas for extending this system:

- **Alerting**: Add SNS notifications when scores drop
- **Multi-page testing**: Test multiple pages (homepage, blog posts, etc.)
- **CI/CD integration**: Run on every deploy via GitHub Actions
- **Historical comparisons**: "Score improved 15% since last month"
- **Automated remediation**: Trigger image optimization when needed
- **Slack integration**: Post weekly reports to Slack
- **Custom metrics**: Track business-specific performance KPIs

## Contributing

This is a working example for a blog post. Feel free to:
- Open issues for bugs or questions
- Submit PRs with improvements
- Fork and customize for your use case

## License

MIT License - use freely for personal or commercial projects

## Resources

- [PageSpeed Insights API Documentation](https://developers.google.com/speed/docs/insights/v5/get-started)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Chart.js Documentation](https://www.chartjs.org/)

## Questions?

Open an issue on GitHub or email me at your@email.com

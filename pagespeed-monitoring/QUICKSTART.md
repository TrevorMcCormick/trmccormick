# PageSpeed Monitoring - Quick Start Guide

Get up and running in 15 minutes.

## Prerequisites Checklist

- [ ] AWS Account with CLI configured (`aws configure`)
- [ ] Terraform installed (`terraform --version`)
- [ ] Python 3.11+ installed
- [ ] Hugo website repository
- [ ] Google Cloud account (free tier)

## Step-by-Step Setup

### 1. Get PageSpeed API Key (5 minutes)

1. Visit https://console.cloud.google.com/apis/credentials
2. Create a new project (or select existing)
3. Click "Enable APIs and Services"
4. Search for "PageSpeed Insights API"
5. Click "Enable"
6. Go back to "Credentials" → "Create Credentials" → "API Key"
7. Copy the API key (looks like: `AIzaSyD...`)

**Note:** No credit card required for PageSpeed API!

### 2. Configure AWS (2 minutes)

```bash
# Verify AWS credentials work
aws sts get-caller-identity

# Should show your account ID and user
```

If this fails:
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter region: us-east-1
# Enter output format: json
```

### 3. Deploy Infrastructure (5 minutes)

```bash
cd pagespeed-monitoring/terraform

# Copy and edit configuration
cp terraform.tfvars.example terraform.tfvars

# Edit with your values (use nano, vim, or any editor)
nano terraform.tfvars
```

**Minimum required values:**
```hcl
target_website_url = "https://trmccormick.com"
github_repo        = "yourusername/trmccormick"
pagespeed_api_key  = "AIzaSyD..."  # Your key from step 1
```

Deploy:
```bash
# Initialize
terraform init

# Deploy (will ask for confirmation)
terraform apply
```

Type `yes` when prompted.

**Save the API Gateway URL from the output!**

### 4. Test It Works (3 minutes)

Run the collector manually to get initial data:

```bash
# Get collector function name from Terraform output
FUNCTION_NAME=$(terraform output -raw collector_lambda_name)

# Invoke it
aws lambda invoke \
  --function-name $FUNCTION_NAME \
  --region us-east-1 \
  /tmp/response.json

# Check the response
cat /tmp/response.json
```

Should see:
```json
{
  "statusCode": 200,
  "body": "{\"message\": \"PageSpeed metrics collected successfully\", ...}"
}
```

Verify data in DynamoDB:
```bash
aws dynamodb scan --table-name pagespeed-metrics --limit 1
```

Should return one item with your website's scores.

### 5. Add to Your Hugo Site (2 minutes)

The shortcode is already in `layouts/shortcodes/pagespeed-chart.html`.

In your blog post markdown:
```markdown
---
title: "My PageSpeed Monitoring"
date: 2025-11-17
---

Here's how my site performs over time:

{{< pagespeed-chart api-url="https://YOUR_API_URL_HERE" >}}
```

Replace `YOUR_API_URL_HERE` with the URL from step 3.

Test locally:
```bash
hugo server -D
```

Visit http://localhost:1313 and check your post!

## Verification Checklist

After setup, verify everything works:

- [ ] Terraform deployed without errors
- [ ] Manual Lambda invocation succeeded
- [ ] DynamoDB has data (`aws dynamodb scan`)
- [ ] API endpoint returns data (`curl https://your-api-url/metrics/summary`)
- [ ] Hugo site shows the chart with data
- [ ] Chart displays scores and commits
- [ ] Clicking a data point opens GitHub

## What Happens Next?

- **Automated checks**: EventBridge will run the collector every Monday at noon UTC
- **Data accumulation**: Each week adds a new data point to your chart
- **GitHub correlation**: Each measurement links to the commit that was live at that time

## Customization

### Change Schedule

Edit `terraform/variables.tf`:
```hcl
variable "schedule_expression" {
  default = "cron(0 12 ? * MON *)"  # Every Monday noon UTC
}
```

Common schedules:
- Daily: `cron(0 12 * * ? *)`
- Weekly (Sunday): `cron(0 12 ? * SUN *)`
- Monthly (1st of month): `cron(0 12 1 * ? *)`

After changing, run `terraform apply`.

### Change Chart Height

In your markdown:
```markdown
{{< pagespeed-chart
    api-url="https://your-api-url"
    height="800"
>}}
```

### Hide Mobile Scores

```markdown
{{< pagespeed-chart
    api-url="https://your-api-url"
    show-mobile="false"
>}}
```

## Troubleshooting

### "No data available" in chart

**Fix:**
1. Manually invoke collector: `aws lambda invoke --function-name pagespeed-monitor-collector /tmp/response.json`
2. Check DynamoDB: `aws dynamodb scan --table-name pagespeed-metrics`
3. Verify API URL in shortcode matches Terraform output
4. Check browser console for CORS errors

### Lambda timeout error

**Fix:** Increase timeout in `terraform/main.tf`:
```hcl
resource "aws_lambda_function" "collector" {
  timeout = 90  # Increase from 60 to 90 seconds
}
```

Then: `terraform apply`

### API returns empty response

**Fix:**
1. Check Lambda logs: `aws logs tail /aws/lambda/pagespeed-monitor-api --follow`
2. Verify DynamoDB has data: `aws dynamodb scan --table-name pagespeed-metrics`
3. Test API directly: `curl https://your-api-url/metrics/latest`

### CORS errors in browser

**Fix:** Update CORS origins in `terraform/variables.tf`:
```hcl
variable "cors_allowed_origins" {
  default = [
    "https://trmccormick.com",
    "https://www.trmccormick.com",
    "http://localhost:1313"
  ]
}
```

Then: `terraform apply`

## Cost Estimates

With weekly checks and moderate website traffic:

| What | How Much |
|------|----------|
| DynamoDB | $0.25/month |
| Lambda | $0.02/month |
| API Gateway | $0.10/month |
| **Total** | **~$0.40/month** |

First month might be $0 due to AWS free tier.

## Next Steps

1. **Let it run**: Wait for the weekly EventBridge trigger, or invoke manually to add more data points
2. **Write the blog post**: Document your setup and findings
3. **Share**: Tweet about it, share on LinkedIn, write a post
4. **Extend**: Add alerting, test multiple pages, integrate with CI/CD

## Need Help?

- Check the full [README.md](README.md) for detailed documentation
- View logs: `aws logs tail /aws/lambda/pagespeed-monitor-collector --follow`
- Open an issue on GitHub
- Review [PageSpeed API docs](https://developers.google.com/speed/docs/insights/v5/get-started)

## Clean Up (If Needed)

To remove everything:
```bash
cd terraform
terraform destroy
```

This deletes all AWS resources and data. **Cannot be undone!**

---

**Estimated setup time:** 15 minutes
**Monthly cost:** ~$0.40
**Maintenance:** Zero (fully automated)

Enjoy your self-monitoring website!

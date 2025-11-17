# PageSpeed Monitoring System - Project Overview

## 📊 Complete File Structure

```
trmccormick/                                  # Your Hugo site root
│
├── pagespeed-monitoring/                    # 🆕 New monitoring system
│   ├── lambda/                              # AWS Lambda functions
│   │   ├── collector.py                     # Collects PageSpeed data
│   │   ├── api.py                           # Serves data via API
│   │   └── requirements.txt                 # Python dependencies
│   │
│   ├── terraform/                           # Infrastructure as Code
│   │   ├── main.tf                          # AWS resources definition
│   │   ├── variables.tf                     # Configuration variables
│   │   ├── outputs.tf                       # Output values (API URL, etc.)
│   │   └── terraform.tfvars.example         # Configuration template
│   │
│   ├── scripts/                             # Automation scripts
│   │   ├── deploy.sh                        # Automated deployment
│   │   └── test.sh                          # System verification
│   │
│   ├── .gitignore                           # Prevent committing secrets
│   ├── README.md                            # Full documentation
│   ├── QUICKSTART.md                        # 15-minute setup guide
│   ├── IMPLEMENTATION_SUMMARY.md            # Implementation details
│   └── PROJECT_OVERVIEW.md                  # This file
│
├── layouts/                                 # Hugo layouts
│   └── shortcodes/
│       └── pagespeed-chart.html             # 🆕 Visualization component
│
└── content/                                 # Hugo content
    └── posts/
        └── pagespeed-monitoring/            # 🆕 New blog post
            └── index.md                     # System explanation
```

## 🏗️ Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Cloud                            │
│                                                              │
│  ┌──────────────┐         Every Monday @ Noon               │
│  │ EventBridge  │         cron(0 12 ? * MON *)              │
│  │  Cron Rule   │                                            │
│  └──────┬───────┘                                            │
│         │                                                    │
│         │ Triggers                                           │
│         ▼                                                    │
│  ┌──────────────────────────────────────────┐               │
│  │  Lambda: Collector (Python 3.11)         │               │
│  │  - Timeout: 60s                           │               │
│  │  - Memory: 256 MB                         │               │
│  │  - Environment: API keys, repo info       │               │
│  └──────┬───────────────────────────────────┘               │
│         │                                                    │
│         │ Queries                                            │
│         ▼                                                    │
│  ┌─────────────────────┐  ┌──────────────────┐             │
│  │ External APIs:      │  │ GitHub API:       │             │
│  │ - PageSpeed Desktop │  │ - Latest commit   │             │
│  │ - PageSpeed Mobile  │  │ - Commit message  │             │
│  │ - Lighthouse data   │  │ - Author          │             │
│  └─────────────────────┘  └──────────────────┘             │
│         │                         │                          │
│         │                         │                          │
│         └────────┬────────────────┘                          │
│                  │                                           │
│                  │ Stores results                            │
│                  ▼                                           │
│  ┌──────────────────────────────────────────┐               │
│  │  DynamoDB: pagespeed-metrics             │               │
│  │  - Partition Key: timestamp              │               │
│  │  - Sort Key: url                         │               │
│  │  - On-demand billing                     │               │
│  │  - Point-in-time recovery enabled        │               │
│  │  - Encryption at rest                    │               │
│  │                                           │               │
│  │  Stores:                                  │               │
│  │  - Performance scores (desktop/mobile)   │               │
│  │  - Core Web Vitals (LCP, FID, CLS)       │               │
│  │  - Timing metrics (FCP, TTI, TBT, SI)    │               │
│  │  - Optimization opportunities             │               │
│  │  - Diagnostics                            │               │
│  │  - Git commit correlation                 │               │
│  └──────┬───────────────────────────────────┘               │
│         │                                                    │
│         │ Reads data                                         │
│         ▼                                                    │
│  ┌──────────────────────────────────────────┐               │
│  │  Lambda: API (Python 3.11)               │               │
│  │  - Timeout: 10s                           │               │
│  │  - Memory: 128 MB                         │               │
│  │  - Endpoints:                             │               │
│  │    • GET /metrics                         │               │
│  │    • GET /metrics/latest                  │               │
│  │    • GET /metrics/summary                 │               │
│  └──────┬───────────────────────────────────┘               │
│         │                                                    │
│         │ Invoked by                                         │
│         ▼                                                    │
│  ┌──────────────────────────────────────────┐               │
│  │  API Gateway (HTTP API)                  │               │
│  │  - CORS enabled                           │               │
│  │  - Cache: 5 minutes                       │               │
│  │  - HTTPS only                             │               │
│  │  - Public endpoint                        │               │
│  └──────┬───────────────────────────────────┘               │
│         │                                                    │
└─────────┼────────────────────────────────────────────────────┘
          │
          │ HTTPS GET requests
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│                  Your Website (Hugo)                         │
│                                                              │
│  ┌──────────────────────────────────────────┐               │
│  │  Blog Post: pagespeed-monitoring/        │               │
│  │             index.md                      │               │
│  │                                           │               │
│  │  Contains shortcode:                      │               │
│  │  {{< pagespeed-chart api-url="..." >}}   │               │
│  └──────┬───────────────────────────────────┘               │
│         │                                                    │
│         │ Renders                                            │
│         ▼                                                    │
│  ┌──────────────────────────────────────────┐               │
│  │  Shortcode: pagespeed-chart.html         │               │
│  │  - Fetches data from API Gateway         │               │
│  │  - Renders with Chart.js                 │               │
│  │  - Shows summary cards                   │               │
│  │  - Displays opportunities                │               │
│  │  - Click-to-GitHub functionality         │               │
│  └──────────────────────────────────────────┘               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 Data Flow

### 1. Weekly Collection (Automated)

```
EventBridge Timer
    → Trigger Lambda Collector
    → Query PageSpeed API (desktop + mobile)
    → Query GitHub API (latest commit)
    → Extract metrics from Lighthouse results
    → Build DynamoDB item with all data
    → Store in DynamoDB
```

**Runs:** Every Monday at noon UTC
**Duration:** ~30-60 seconds
**Cost per run:** ~$0.001

### 2. User Views Website

```
User visits blog post
    → Browser loads HTML
    → Shortcode JavaScript executes
    → Fetches API Gateway /metrics/summary
    → API Gateway invokes Lambda
    → Lambda scans DynamoDB
    → Lambda computes statistics
    → Returns JSON response
    → JavaScript renders Chart.js visualization
    → User sees current scores, trends, chart, opportunities
```

**Duration:** ~200-500ms (first request), ~50ms (cached)
**Cost per view:** ~$0.0001

### 3. User Clicks Data Point

```
User clicks chart point
    → JavaScript gets commit SHA from data
    → Opens GitHub URL in new tab
    → User sees the exact commit that was live during that measurement
```

## 📈 What Gets Measured

### Performance Scores (0-100)
- Desktop performance score
- Mobile performance score
- Average score
- Accessibility score
- Best practices score
- SEO score

### Core Web Vitals
- **LCP** (Largest Contentful Paint) - Loading performance
- **FID** (First Input Delay) - Interactivity
- **CLS** (Cumulative Layout Shift) - Visual stability

### Timing Metrics (milliseconds)
- **FCP** (First Contentful Paint)
- **TTI** (Time to Interactive)
- **TBT** (Total Blocking Time)
- **SI** (Speed Index)

### Actionable Insights
- **Opportunities** - Specific ways to improve with estimated time savings
  - "Properly size images" → Save 2.1s
  - "Reduce unused JavaScript" → Save 0.8s
  - "Serve images in next-gen formats" → Save 1.5s

- **Diagnostics** - Things affecting performance
  - "Avoid enormous network payloads"
  - "Minimize main-thread work"
  - "Reduce JavaScript execution time"

### Git Correlation
- Commit SHA (full and short)
- Commit message
- Author name
- Commit date
- GitHub URL

## 💰 Cost Breakdown

### Monthly (with weekly checks + 1000 website views)

| Component | Usage | Unit Cost | Monthly Cost |
|-----------|-------|-----------|--------------|
| **DynamoDB** | | | |
| Write requests | 4/month | $1.25/million | $0.000005 |
| Read requests | ~500/month | $0.25/million | $0.0001 |
| Storage | ~1 MB | $0.25/GB | $0.0003 |
| **DynamoDB Total** | | | **$0.25** |
| | | | |
| **Lambda (Collector)** | | | |
| Invocations | 4/month | $0.20/million | $0.0000008 |
| Duration | 4 × 30s @ 256MB | $0.0000166667/GB-sec | $0.005 |
| **Collector Total** | | | **$0.01** |
| | | | |
| **Lambda (API)** | | | |
| Invocations | 500/month | $0.20/million | $0.0001 |
| Duration | 500 × 100ms @ 128MB | $0.0000166667/GB-sec | $0.001 |
| **API Total** | | | **$0.01** |
| | | | |
| **API Gateway** | | | |
| Requests | 500/month | $1.00/million | $0.0005 |
| Data transfer | Negligible | $0.09/GB | $0.01 |
| **API Gateway Total** | | | **$0.10** |
| | | | |
| **CloudWatch Logs** | ~10 MB | $0.50/GB | **$0.05** |
| | | | |
| **TOTAL MONTHLY COST** | | | **~$0.42** |

### Free Tier Services
- PageSpeed Insights API: Free (25,000 requests/day)
- GitHub API: Free for public repositories
- EventBridge: Free (first 14 million invocations/month)

### First Year Estimate
With AWS Free Tier (first 12 months):
- Lambda: 1M free requests/month + 400,000 GB-seconds
- DynamoDB: 25 GB storage + 25 read/write capacity units
- API Gateway: First million requests free

**Effective cost for first year:** ~$0-5 total

## 🚀 Deployment Steps

### Prerequisites (5 minutes)
1. Get PageSpeed API key from Google Cloud Console
2. Configure AWS CLI (`aws configure`)
3. Install Terraform

### Deployment (10 minutes)
1. Configure `terraform/terraform.tfvars`
2. Run `./scripts/deploy.sh` or `terraform apply`
3. Note the API Gateway URL from output
4. Update blog post shortcode with API URL
5. Run `./scripts/test.sh` to verify

### Verification (2 minutes)
1. Manually trigger collector Lambda
2. Check DynamoDB for data
3. Test API endpoints
4. View Hugo site locally
5. Deploy Hugo site to production

**Total setup time:** ~15-20 minutes

## 🔒 Security Features

✅ **Implemented:**
- DynamoDB encryption at rest (AWS managed KMS)
- Point-in-time recovery enabled
- Least-privilege IAM roles (Lambda can only access its specific resources)
- HTTPS-only API Gateway
- Secrets not committed to Git (`.gitignore`)
- CloudWatch logs for audit trail
- No public write access (only Lambda can write to DynamoDB)

⚠️ **Production Recommendations:**
- Store API keys in AWS Secrets Manager (not environment variables)
- Add API Gateway authentication (API key or AWS Cognito)
- Restrict CORS to specific domains (not wildcard `*`)
- Enable AWS CloudTrail for compliance
- Set up CloudWatch alarms for anomalies
- Add rate limiting on API Gateway

## 📊 Visualization Features

The Chart.js visualization includes:

### Summary Cards
- Current desktop score (color-coded: green ≥90, yellow ≥50, red <50)
- Current mobile score (color-coded)
- Total measurements count
- Trend since first check ("+5.3 points")
- Date range of measurements

### Interactive Chart
- Line graph showing scores over time
- Dual lines (desktop + mobile)
- Hover tooltips showing:
  - Date of measurement
  - Score values
  - Commit SHA
  - Commit message
  - "Click to view on GitHub"
- Click interaction opens GitHub commit in new tab
- Responsive design (adapts to screen size)

### Opportunities Section
- Top 3 desktop optimization opportunities
- Top 3 mobile optimization opportunities
- Each showing:
  - Title (e.g., "Properly size images")
  - Description (why it matters)
  - Estimated savings in seconds

## 🛠️ Customization Options

### Change Collection Frequency
```hcl
# In terraform/variables.tf
schedule_expression = "cron(0 12 ? * MON *)"  # Weekly (default)
# OR
schedule_expression = "cron(0 6 * * ? *)"    # Daily at 6 AM UTC
# OR
schedule_expression = "cron(0 0 1 * ? *)"    # Monthly (1st at midnight)
```

### Add Alerting
```python
# In lambda/collector.py
if desktop_score < 80:  # Threshold
    sns.publish(
        TopicArn=os.environ['SNS_TOPIC_ARN'],
        Subject=f'PageSpeed Alert: Score = {desktop_score}',
        Message='Performance dropped below threshold'
    )
```

### Test Multiple URLs
```python
# In lambda/collector.py
urls = [
    'https://trmccormick.com',
    'https://trmccormick.com/posts/simple-infrastructure',
    'https://trmccormick.com/about'
]

for url in urls:
    desktop_data = fetch_pagespeed_data(url, 'desktop', api_key)
    # ... process and store
```

### Change Chart Colors
```javascript
// In layouts/shortcodes/pagespeed-chart.html
datasets: [
  {
    label: 'Desktop',
    borderColor: '#4285f4',  // Change to any hex color
    backgroundColor: 'rgba(66, 133, 244, 0.1)',
    // ...
  }
]
```

## 📚 Documentation

1. **README.md** - Complete technical documentation
   - All features explained
   - API reference
   - Troubleshooting guide
   - Configuration options

2. **QUICKSTART.md** - 15-minute setup guide
   - Step-by-step instructions
   - Minimal configuration
   - Common issues and fixes

3. **IMPLEMENTATION_SUMMARY.md** - Implementation details
   - Architecture explanation
   - Code walkthrough
   - Data structures
   - Cost analysis

4. **PROJECT_OVERVIEW.md** (this file) - Visual overview
   - File structure
   - Architecture diagrams
   - Data flow charts
   - Feature summary

5. **Blog Post** (`content/posts/pagespeed-monitoring/index.md`)
   - Narrative explanation
   - Why this approach
   - Lessons learned
   - Live demonstration

## 🔧 Maintenance

### Required
- **None!** System is fully automated

### Optional
- Review opportunities monthly
- Update Lambda runtime when AWS announces deprecation
- Adjust schedule if needed
- Add more URLs to monitor

### Recommended
- Check CloudWatch logs occasionally for errors
- Review DynamoDB item count (should match expected measurements)
- Update blog post with findings
- Share improvements via GitHub

## 🚨 Monitoring & Debugging

### View Logs
```bash
# Real-time collector logs
aws logs tail /aws/lambda/pagespeed-monitor-collector --follow

# Real-time API logs
aws logs tail /aws/lambda/pagespeed-monitor-api --follow
```

### Manual Trigger
```bash
aws lambda invoke \
  --function-name pagespeed-monitor-collector \
  --region us-east-1 \
  /tmp/response.json && cat /tmp/response.json
```

### Check Data
```bash
# Count measurements
aws dynamodb scan \
  --table-name pagespeed-metrics \
  --select COUNT

# View latest data
aws dynamodb scan \
  --table-name pagespeed-metrics \
  --limit 1
```

### Test API
```bash
# Get summary (what the chart uses)
curl https://YOUR_API_URL/metrics/summary | jq

# Get all historical data
curl https://YOUR_API_URL/metrics | jq

# Get latest measurement only
curl https://YOUR_API_URL/metrics/latest | jq
```

### Run Test Suite
```bash
cd pagespeed-monitoring
./scripts/test.sh
```

## 🎯 Success Metrics

After deployment, you should see:

✅ **Infrastructure**
- Terraform apply succeeds without errors
- 8 AWS resources created (DynamoDB, 2 Lambdas, API Gateway, EventBridge, 3 IAM roles)
- API Gateway URL accessible

✅ **Data Collection**
- Collector Lambda runs successfully
- DynamoDB contains items (one per week minimum)
- GitHub commit correlation working

✅ **API**
- All three endpoints return 200 status
- `/metrics/summary` returns valid JSON
- CORS headers present in response

✅ **Website**
- Chart renders on Hugo site
- Summary cards show actual scores
- Opportunities list populated
- Clicking chart points opens GitHub

✅ **Automation**
- EventBridge rule enabled
- Weekly measurements added automatically
- Historical trend visible in chart

## 📈 Future Enhancements

### Phase 2 Ideas
1. **Slack Integration**
   - Post weekly summary to Slack channel
   - Alert on significant drops

2. **Multi-Page Testing**
   - Test top 10 pages
   - Compare performance across page types
   - Identify regression patterns

3. **CI/CD Integration**
   - Run on every deploy via GitHub Actions
   - Block merges if score drops >10 points
   - Comment results on pull requests

4. **Advanced Analytics**
   - Week-over-week comparisons
   - Month-over-month trends
   - Seasonal pattern detection
   - Correlation with traffic changes

5. **Automated Remediation**
   - Trigger image optimization Lambda
   - Auto-generate improvement PRs
   - Schedule maintenance based on opportunities

6. **Cost Tracking**
   - Query AWS Cost Explorer API
   - Correlate infrastructure costs with performance
   - Show ROI of optimizations

## 📞 Support & Contributing

### Getting Help
1. Check the documentation (README.md, QUICKSTART.md)
2. Run the test script (`./scripts/test.sh`)
3. Review CloudWatch logs
4. Open a GitHub issue with logs and error messages

### Contributing
- Fork the repository
- Make improvements
- Submit pull request
- Share your customizations

### Sharing
If you use this system:
- Write about it on your blog
- Share the GitHub repo
- Tweet your results
- Help others implement it

---

## 🎉 You're All Set!

This is a complete, production-ready system that will:
- Monitor your website's performance automatically
- Store historical data with Git correlation
- Provide beautiful visualizations
- Cost less than $0.50/month
- Require zero maintenance

**Next step:** Run `./scripts/deploy.sh` and watch it come to life!

Questions? Check the docs or open an issue on GitHub.

Happy monitoring! 📊

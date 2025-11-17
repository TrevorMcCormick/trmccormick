---
title: "Building a Self-Monitoring Website with PageSpeed Insights and AWS"
date: 2025-11-17T12:00:00-05:00
draft: true
tags: [AWS, Performance, Monitoring, Lambda, DynamoDB, API Gateway]
description: "How I built a serverless PageSpeed monitoring system that tracks performance over time, correlates metrics with Git commits, and costs less than $1/month"
---

Your website's performance matters. Google uses it as a ranking signal. Users abandon slow sites. But monitoring performance continuously is tedious and easy to forget.

So I built a system that monitors itself. Every week, it checks its own PageSpeed Insights score, stores the results, and displays them right here on this page. Total cost: about $0.50 monthly. Setup time: one afternoon.

Here's how it works—and how you can build the same thing.

## The Architecture

```
┌─────────────────┐
│ EventBridge     │  Every Monday at noon
│ Cron Rule       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐      ┌──────────────────┐
│ Lambda:         │─────▶│ PageSpeed        │
│ Collector       │      │ Insights API     │
└────────┬────────┘      └──────────────────┘
         │                       │
         │                       ▼
         │              ┌──────────────────┐
         │              │ GitHub API       │
         │              │ (latest commit)  │
         │              └──────────────────┘
         ▼
┌─────────────────┐
│ DynamoDB        │
│ - Scores        │
│ - Core Vitals   │
│ - Opportunities │
│ - Commit data   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐      ┌──────────────────┐
│ Lambda: API     │◀─────│ API Gateway      │
└─────────────────┘      └────────┬─────────┘
                                  │
                                  ▼
                         ┌──────────────────┐
                         │ This Page        │
                         │ (Chart.js viz)   │
                         └──────────────────┘
```

The flow is simple:

1. **EventBridge** triggers a Lambda function every Monday
2. **Lambda** queries Google PageSpeed Insights API for desktop and mobile scores
3. **Lambda** fetches the latest Git commit from GitHub API
4. **Lambda** stores everything in DynamoDB with the commit SHA
5. **API Gateway** + second Lambda serve the data as JSON
6. **This page** fetches and visualizes the data with Chart.js

All serverless. No servers to patch. No databases to manage. Just code and AWS-managed services.

## The Live Results

{{< pagespeed-chart api-url="https://8z1v0z8s97.execute-api.us-east-1.amazonaws.com" >}}

The chart above shows actual data. Each point correlates with a specific Git commit. Click a point to see what changed on GitHub.

## Why This Matters

### Performance as a Product Metric

PageSpeed Insights measures what Google's search algorithm cares about:
- **Largest Contentful Paint (LCP)**: How fast the main content loads
- **First Input Delay (FID)**: How quickly the site responds to user input
- **Cumulative Layout Shift (CLS)**: How stable the layout is during load

These aren't vanity metrics. They affect search rankings and user experience. This site is pure static HTML—it should be fast. If the score drops, something broke.

### Connecting Code to Metrics

The system correlates each measurement with a Git commit. When performance changes, I can see exactly what caused it.

Example: If I add a large JavaScript library and the score drops 15 points, the chart shows it. I hover over that data point, see the commit message "Add analytics library," click through to GitHub, and review the change.

This isn't theoretical. On a previous project, we added social media share buttons. Performance dropped 12 points. We saw it in the data, traced it to the commit, and replaced the heavy third-party script with a lightweight custom implementation. Score recovered in the next measurement.

### Automation Eliminates Inconsistency

Manual testing is inconsistent. You test when you remember. You test after major changes. You don't test the week nothing shipped—but dependencies auto-update, CDN behavior changes, third-party scripts evolve.

Automated weekly checks catch regressions you'd miss manually.

## The Implementation

### Phase 1: Data Collection

The collector Lambda does four things:

1. **Query PageSpeed Insights API** for desktop and mobile strategies
2. **Fetch latest commit** from GitHub API
3. **Extract relevant metrics** from the Lighthouse results
4. **Store in DynamoDB** with timestamp as partition key

Key excerpt from `collector.py`:

```python
def lambda_handler(event, context):
    # Fetch latest commit
    commit_data = fetch_github_commit(github_repo, github_token)

    # Run PageSpeed tests
    desktop_data = fetch_pagespeed_data(target_url, 'desktop', api_key)
    mobile_data = fetch_pagespeed_data(target_url, 'mobile', api_key)

    # Extract metrics
    desktop_metrics = extract_metrics(desktop_data, 'desktop')
    mobile_metrics = extract_metrics(mobile_data, 'mobile')

    # Build and store DynamoDB item
    item = build_dynamodb_item(
        timestamp=datetime.utcnow().isoformat(),
        url=target_url,
        desktop_metrics=desktop_metrics,
        mobile_metrics=mobile_metrics,
        commit_data=commit_data
    )

    store_metrics(table_name, item)
```

The `extract_metrics` function pulls performance scores, Core Web Vitals, and—critically—**opportunities**. These are specific recommendations from Lighthouse about what to improve.

For example:
- "Properly size images" - potential savings: 2.1s
- "Reduce unused JavaScript" - potential savings: 0.8s
- "Serve images in next-gen formats" - potential savings: 1.5s

These actionable insights appear in the "Opportunities" section below the chart.

### Phase 2: Data Storage

DynamoDB table schema:

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | String (PK) | ISO timestamp |
| `url` | String (SK) | Tested URL |
| `desktop` | Map | All desktop metrics |
| `mobile` | Map | All mobile metrics |
| `commit` | Map | Git SHA, message, author, URL |
| `desktop_score` | Number | For quick queries |
| `mobile_score` | Number | For quick queries |
| `average_score` | Number | Computed average |

Why DynamoDB?

- **Serverless**: No capacity planning
- **Pay-per-request**: Weekly writes cost pennies
- **Fast reads**: The API Lambda scans once, API Gateway caches for 5 minutes
- **Point-in-time recovery**: Enabled for data protection

This workload has maybe 50 writes annually and a few hundred reads monthly. DynamoDB's on-demand pricing makes that nearly free.

### Phase 3: API Layer

The API Lambda serves three endpoints:

- `GET /metrics` - All historical data
- `GET /metrics/latest` - Most recent measurement
- `GET /metrics/summary` - Statistics and trends

The `/metrics/summary` endpoint does the heavy lifting. It scans DynamoDB, calculates trends, and returns:

```json
{
  "total_measurements": 12,
  "current": {
    "desktop_score": 98,
    "mobile_score": 92,
    "commit": { "sha": "a3b2c1d", "message": "Optimize images" }
  },
  "statistics": {
    "desktop": {
      "current": 98,
      "average": 95.2,
      "trend": +5.3
    },
    "mobile": {
      "current": 92,
      "average": 89.1,
      "trend": +3.8
    }
  },
  "top_opportunities": {
    "desktop": [...],
    "mobile": [...]
  },
  "historical_data": [...]
}
```

The frontend consumes this to render summary cards, the chart, and optimization suggestions.

### Phase 4: Visualization

The Hugo shortcode `pagespeed-chart.html` fetches the summary endpoint and renders:

1. **Summary cards** showing current scores and trends
2. **Line chart** with Chart.js displaying historical performance
3. **Opportunities list** showing top 3 optimizations for desktop and mobile

Chart.js configuration enables click-to-GitHub:

```javascript
onClick: (event, elements) => {
  if (elements.length > 0) {
    const index = elements[0].index;
    const commitSha = historicalData[index].commit_sha;
    const repoUrl = 'https://github.com/youruser/yourrepo';
    window.open(`${repoUrl}/commit/${commitSha}`, '_blank');
  }
}
```

Clicking a data point opens the corresponding commit on GitHub. You see the performance change and the code change side-by-side.

## Infrastructure as Code

Everything deploys via Terraform. The complete infrastructure is ~300 lines:

- DynamoDB table with encryption and point-in-time recovery
- Two Lambda functions with IAM roles scoped to minimum permissions
- API Gateway HTTP API with CORS configuration
- EventBridge rule for weekly cron trigger
- CloudWatch log groups for debugging

To deploy:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform apply
```

Terraform outputs the API Gateway URL. Copy it into the Hugo shortcode parameter.

## The Economics

Monthly AWS costs (approximate):

| Service | Usage | Cost |
|---------|-------|------|
| DynamoDB | ~4 writes/month, ~200 reads/month | $0.25 |
| Lambda (collector) | 4 invocations/month @ 30s each | $0.01 |
| Lambda (API) | ~200 invocations/month @ 100ms each | $0.01 |
| API Gateway | ~200 requests/month | $0.10 |
| CloudWatch Logs | Minimal | $0.05 |
| **Total** | | **~$0.42** |

Under 50 cents monthly. The PageSpeed Insights API is free (25,000 requests/day). The GitHub API is free for public repos.

Compare this to commercial monitoring services ($20-100/month) or the operational overhead of self-hosted Lighthouse CI (server costs, maintenance time).

## Lessons from Building This

### 1. Separate Data Collection from Presentation

The collector Lambda and API Lambda are independent. I can change visualization libraries without touching data collection. I can add Slack notifications by reading DynamoDB directly. The data exists independently of how it's displayed.

In larger systems, this separation is critical. Data pipelines should not care about dashboards. Dashboards should not care about extraction logic.

### 2. Start with Manual Triggers, Automate Later

Initially, I ran the collector Lambda manually via AWS CLI:

```bash
aws lambda invoke --function-name pagespeed-collector output.json
```

This let me debug API responses, DynamoDB schema, and error handling without waiting for cron triggers. Only after confirming it worked did I add EventBridge.

For data pipelines at work, we follow the same pattern: manual execution first, scheduling after validation.

### 3. Make Infrastructure Reproducible

The Terraform code is versioned in Git. If I delete everything, I can recreate it in 5 minutes. If someone asks "how is this deployed?" the answer is `terraform apply`, not a series of console clicks.

This matters more as systems grow. One-off manual infrastructure becomes tribal knowledge. Code is documentation.

### 4. Monitor What Changes, Not What's Stable

This system checks weekly, not daily or hourly. Why?

Because this site is static HTML. It changes infrequently. Daily checks would generate identical data. Weekly is enough to catch regressions from dependency updates or CDN configuration changes.

If this were an e-commerce site with frequent deploys, I'd run checks on every deploy via CI/CD instead of cron.

## Possible Extensions

This is the MVP. Here's what I'd add for a production data product:

### Alerting

Add an SNS topic. If the score drops more than 10 points, send an email or Slack message:

```python
if current_score < previous_score - 10:
    sns.publish(
        TopicArn=os.environ['ALERT_TOPIC_ARN'],
        Subject='PageSpeed Alert: Score Dropped',
        Message=f'Performance dropped {previous_score - current_score} points'
    )
```

### Multiple Pages

Test the homepage, key landing pages, blog posts. Add a `page_type` field to DynamoDB. Track performance by content type.

### Automated Remediation

If "Properly size images" appears in opportunities repeatedly, trigger a Lambda that runs image optimization. If "Reduce unused CSS" appears, trigger PurgeCSS. Close the loop from detection to fix.

### Lighthouse CI Integration

Run PageSpeed checks in CI/CD on every pull request. Comment results directly on GitHub PRs. Block merges if performance drops below threshold.

### Cost Tracking

Add AWS Cost Explorer API calls. Correlate infrastructure costs with performance. If caching improves, quantify the CloudFront cost reduction.

## Matching Tools to Problems (Again)

This monitoring system uses the same principles as the site itself: serverless, event-driven, minimal operational overhead.

I didn't set up Grafana and Prometheus because this doesn't need continuous metrics. I didn't deploy Lighthouse CI on EC2 because four Lambda invocations monthly are cheaper than a t3.micro instance.

The tool matches the problem. Weekly measurements of a static site don't require enterprise monitoring infrastructure.

But the pattern scales. Replace "PageSpeed score" with "data pipeline SLA" or "dashboard load time" or "API response percentiles" and the architecture works. EventBridge triggers a collector. Collector stores in DynamoDB or Timestream. API serves it. Chart.js or D3.js visualizes it.

## The Meta-Insight

The site monitors its own performance. The blog post explaining the system includes the live system. The infrastructure code is public. Anyone can clone the repo and deploy their own version.

This is self-documenting infrastructure. The explanation is the implementation. The implementation proves the explanation works.

In data products, this matters. If the dashboard showing pipeline health is built on the same patterns as the pipeline itself, the dashboard becomes a reference implementation. New team members see working code that follows established patterns.

The best documentation is code that runs in production.

---

**Full source code**: [GitHub repository](https://github.com/yourusername/trmccormick) (pagespeed-monitoring directory)

**Deployment instructions**: See the README in `pagespeed-monitoring/`

**Questions or improvements?** Open an issue or PR. This system evolved from initial concept to working implementation in an afternoon. It can continue evolving.

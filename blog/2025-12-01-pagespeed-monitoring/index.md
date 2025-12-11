---
title: "Automating PageSpeed Insights Scores"
description: "Build a serverless PageSpeed monitoring system with AWS Lambda, DynamoDB, and SNS alerts."
date: 2025-12-01
authors: [trevor]
tags: [aws, data-engineering]
image: /img/social/2025-12-01-pagespeed-monitoring.png
hide_table_of_contents: true
---

import PageSpeedMetrics from '@site/src/components/PageSpeedMetrics';
import InteractiveMermaid from '@site/src/components/InteractiveMermaid';

Because why would I *manually* go to [Page Speed Insights](https://pagespeed.web.dev/) to get my website score?

<!-- truncate -->

Hover over the dots to see the date and click on the commit hash to dig into the report.

<PageSpeedMetrics />

Here is a simple project that:
- Uses a GitHub webhook to trigger performance analysis on every push to main
- Calls PageSpeed Insights API to measure both mobile and desktop performance
- Stores results in DynamoDB with full commit metadata
- Sends email alerts via SNS when any score drops by 5+ points
- Generates comprehensive markdown reports and commits them back to the repo
- Visualizes trends and opportunities on this page

Here's how it works (click on the boxes to read more):

## Architecture

<InteractiveMermaid
  chart={`%%{init: {'theme':'base', 'themeVariables': { 'clusterBkg':'#f8fafc', 'clusterBorder':'#cbd5e1', 'edgeLabelBackground':'#ffffff'}, 'flowchart': {'nodeSpacing': 35, 'rankSpacing': 55}}}%%
graph TB
    subgraph collection["Data Collection Flow"]
      direction TB
      github-webhook["GitHub<br/><small>Webhook</small>"]
      webhook-gateway["API Gateway<br/><small>Webhook Endpoint</small>"]
      lambda-webhook["Lambda<br/><small>Webhook Handler</small>"]
      lambda-collector["Lambda<br/><small>Collector</small>"]

      github-webhook -->|1. POST on push| webhook-gateway
      webhook-gateway -->|2. Invoke| lambda-webhook
      lambda-webhook -->|3. Trigger| lambda-collector
    end

    subgraph external["External APIs"]
      pagespeed["PageSpeed<br/>Insights API"]
      github-api["GitHub API<br/><small>Commit Reports</small>"]
    end

    subgraph storage["Data Storage"]
      dynamodb[("DynamoDB")]
      github-repo["GitHub Repo<br/><small>projects/pagespeed-reports/</small>"]
    end

    subgraph alerting["Alerting"]
      sns["SNS Topic<br/><small>Email Alerts</small>"]
      email["📧 Email<br/><small>Score Drop Alerts</small>"]

      sns -.->|Alert| email
    end

    subgraph api["API Layer"]
      page["trmccormick.com<br/><small>This Page</small>"]
      apigateway["API Gateway<br/><small>Metrics Endpoint</small>"]
      lambda-api["Lambda<br/>API Handler"]

      page -->|10. Fetch JSON| apigateway
      apigateway -->|11. Invoke| lambda-api
    end

    lambda-collector -->|4. Query scores| pagespeed
    pagespeed -.->|5. Return metrics| lambda-collector
    lambda-collector -->|6. Check thresholds| sns
    lambda-collector -->|7. Store in DB| dynamodb
    lambda-collector -->|8. Generate report| github-api
    github-api -.->|9. Commit to repo| github-repo
    lambda-api -->|12. Scan data| dynamodb
    dynamodb -.->|13. Return metrics| lambda-api
    lambda-api -.->|14. Return JSON| apigateway
    apigateway -.->|15. Return data| page

    classDef aws fill:#fff4e6,stroke:#ffb366,stroke-width:2px
    classDef database fill:#eef2ff,stroke:#818cf8,stroke-width:2px
    classDef gateway fill:#fdf2f8,stroke:#f472b6,stroke-width:2px
    classDef pagespeedStyle fill:#eff6ff,stroke:#60a5fa,stroke-width:2px
    classDef githubStyle fill:#f8fafc,stroke:#cbd5e1,stroke-width:2px
    classDef frontend fill:#f0fdf4,stroke:#86efac,stroke-width:2px
    classDef alert fill:#fef2f2,stroke:#fca5a5,stroke-width:2px

    class lambda-collector,lambda-api,lambda-webhook aws
    class dynamodb,github-repo database
    class apigateway,webhook-gateway gateway
    class pagespeed,github-api pagespeedStyle
    class github-webhook githubStyle
    class page frontend
    class sns,email alert`}
  descriptions={{
    "github-webhook": {
      title: "GitHub Webhook",
      description: "When code is pushed to my website repository's main branch, Github sends a POST request to API Gateway.",
    },
    "webhook-gateway": {
      title: "API Gateway Webhook Endpoint",
      description: "Receives GitHub webhook POST request and invokes the webhook handler Lambda.",
    },
    "lambda-webhook": {
      title: "Lambda Webhook Handler",
      description: "Extracts commit metadata, and asynchronously triggers the collector Lambda.",
    },
    "lambda-collector": {
      title: "Lambda Collector",
      description: "Orchestrates data collection by querying PageSpeed Insights API for both mobile and desktop scores, comparing with previous metrics to detect score drops, sending alerts via SNS when thresholds are exceeded, persisting results to DynamoDB, and generating detailed markdown reports that get committed back to the repository.",
    },
    sns: {
      title: "SNS Topic",
      description: "AWS Simple Notification Service topic that receives alerts from the collector Lambda when PageSpeed scores drop by 5+ points. Supports email subscriptions for immediate notifications when performance degrades.",
    },
    email: {
      title: "Email Alerts",
      description: "Email notifications sent when any PageSpeed score (Performance, Accessibility, Best Practices, or SEO) drops by more than the configured threshold on mobile or desktop. Includes before/after scores, affected categories, and commit information for quick investigation.",
    },
    pagespeed: {
      title: "PageSpeed Insights API",
      description: "Google's Lighthouse-powered API that returns performance scores and Core Web Vitals metrics:\n\n• <strong>Largest Contentful Paint (LCP)</strong>:\n&nbsp;&nbsp;&nbsp;&nbsp;Time until the largest content element becomes visible\n• <strong>First Contentful Paint (FCP)</strong>:\n&nbsp;&nbsp;&nbsp;&nbsp;Time until first content renders\n• <strong>Cumulative Layout Shift (CLS)</strong>:\n&nbsp;&nbsp;&nbsp;&nbsp;Measures visual stability\n• <strong>Total Blocking Time (TBT)</strong>:\n&nbsp;&nbsp;&nbsp;&nbsp;Tracks main thread blocking\n• <strong>Speed Index (SI)</strong>:\n&nbsp;&nbsp;&nbsp;&nbsp;How quickly content is visually displayed",
    },
    "github-api": {
      title: "GitHub API",
      description: "Used to commit generated PageSpeed reports to the repository. Each report is a markdown file containing full Lighthouse results, optimization opportunities, and commit metadata.",
    },
    dynamodb: {
      title: "DynamoDB",
      description: "NoSQL table storing performance metrics, Core Web Vitals, and commit metadata with timestamp-based keys for historical tracking.",
    },
    "github-repo": {
      title: "GitHub Repository (projects/pagespeed-reports/)",
      description: "Version-controlled storage of all PageSpeed reports. Each push to main generates a new report file named by commit SHA, creating a permanent audit trail of performance over time.",
    },
    apigateway: {
      title: "API Gateway Metrics Endpoint",
      description: "HTTP API exposing DynamoDB metrics to the frontend with CORS support for cross-origin requests from the blog.",
    },
    "lambda-api": {
      title: "Lambda API Handler",
      description: "Scans DynamoDB for historical metrics, computes trends, and returns formatted JSON for visualization.",
    },
    page: {
      title: "This Blog Post",
      description: "React component that displays performance data fetched at build time from a static JSON file. Data is pre-fetched from the API during the Docusaurus build process, eliminating client-side API calls and improving page load performance.",
    }
  }}
/>

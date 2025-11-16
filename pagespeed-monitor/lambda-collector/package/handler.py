"""
PageSpeed Insights Data Collector Lambda

Queries Google PageSpeed Insights API, correlates with GitHub commits,
and stores results in DynamoDB for historical tracking.
"""

import boto3
import requests
import os
import json
from datetime import datetime
from decimal import Decimal


class DecimalEncoder(json.JSONEncoder):
    """Helper to convert Decimal objects to floats for JSON serialization"""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super().default(obj)


def handler(event, context):
    """
    Main Lambda handler that orchestrates PageSpeed data collection

    Environment Variables:
        PAGESPEED_API_KEY: Google PageSpeed Insights API key
        GITHUB_REPO: GitHub repository in format 'owner/repo'
        GITHUB_TOKEN: GitHub personal access token (optional, for private repos)
        TARGET_URL: Website URL to test (default: https://trmccormick.com)
        DYNAMODB_TABLE: DynamoDB table name (default: pagespeed-metrics)
    """

    # Configuration from environment variables
    api_key = os.environ.get('PAGESPEED_API_KEY', '')
    github_repo = os.environ.get('GITHUB_REPO', 'trmccormick/trmccormick')
    github_token = os.environ.get('GITHUB_TOKEN', '')
    target_url = os.environ.get('TARGET_URL', 'https://trmccormick.com')
    table_name = os.environ.get('DYNAMODB_TABLE', 'pagespeed-metrics')

    try:
        # 1. Fetch latest GitHub commit
        print(f"Fetching latest commit from GitHub repo: {github_repo}")
        commit_data = fetch_github_commit(github_repo, github_token)

        # 2. Run PageSpeed Insights tests for both desktop and mobile
        print(f"Running PageSpeed Insights for {target_url}")
        desktop_data = fetch_pagespeed_data(target_url, 'desktop', api_key)
        mobile_data = fetch_pagespeed_data(target_url, 'mobile', api_key)

        # 3. Extract and structure metrics
        timestamp = datetime.utcnow().isoformat()

        desktop_metrics = extract_metrics(desktop_data, 'desktop')
        mobile_metrics = extract_metrics(mobile_data, 'mobile')

        # 4. Build DynamoDB item
        item = build_dynamodb_item(
            timestamp=timestamp,
            url=target_url,
            desktop_metrics=desktop_metrics,
            mobile_metrics=mobile_metrics,
            commit_data=commit_data
        )

        # 5. Store in DynamoDB
        print(f"Storing metrics in DynamoDB table: {table_name}")
        store_metrics(table_name, item)

        # 6. Generate and commit PageSpeed report to repository
        if github_token:  # Only if we have write access
            print(f"Generating PageSpeed report for commit {commit_data['sha'][:7]}")
            report_path = f"pagespeed-reports/{commit_data['sha']}.md"
            report_content = generate_pagespeed_report(
                commit_data=commit_data,
                desktop_metrics=desktop_metrics,
                mobile_metrics=mobile_metrics,
                target_url=target_url,
                timestamp=timestamp
            )

            try:
                commit_file_to_repo(
                    repo=github_repo,
                    token=github_token,
                    file_path=report_path,
                    content=report_content,
                    commit_message=f"Add PageSpeed report for {commit_data['sha'][:7]}",
                    branch='main'
                )
                print(f"Successfully committed report to {report_path}")
            except Exception as e:
                print(f"Warning: Could not commit report to repo: {str(e)}")
                # Don't fail the whole Lambda if report commit fails

        print("Successfully collected and stored PageSpeed metrics")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'PageSpeed metrics collected successfully',
                'timestamp': timestamp,
                'desktop_score': desktop_metrics['performance_score'],
                'mobile_score': mobile_metrics['performance_score'],
                'commit': commit_data['sha'][:7]
            })
        }

    except Exception as e:
        print(f"Error collecting PageSpeed metrics: {str(e)}")
        import traceback
        traceback.print_exc()

        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }


def fetch_github_commit(repo, token=None):
    """
    Fetch the latest commit from GitHub repository

    Args:
        repo: Repository in format 'owner/repo'
        token: Optional GitHub personal access token

    Returns:
        dict: Commit information including SHA, message, author, and URL
    """
    url = f'https://api.github.com/repos/{repo}/commits/main'
    headers = {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'PageSpeed-Monitor-Lambda'
    }

    if token:
        headers['Authorization'] = f'token {token}'

    response = requests.get(url, headers=headers, timeout=10)
    response.raise_for_status()

    commit = response.json()

    return {
        'sha': commit['sha'],
        'short_sha': commit['sha'][:7],
        'message': commit['commit']['message'].split('\n')[0],  # First line only
        'author': commit['commit']['author']['name'],
        'date': commit['commit']['author']['date'],
        'url': commit['html_url']
    }


def fetch_pagespeed_data(url, strategy, api_key):
    """
    Query Google PageSpeed Insights API

    Args:
        url: Target URL to analyze
        strategy: 'desktop' or 'mobile'
        api_key: Google API key

    Returns:
        dict: Complete PageSpeed Insights response
    """
    endpoint = 'https://www.googleapis.com/pagespeedonline/v5/runPagespeed'

    params = {
        'url': url,
        'strategy': strategy,
        'category': ['performance', 'accessibility', 'best-practices', 'seo']
    }

    if api_key:
        params['key'] = api_key

    response = requests.get(endpoint, params=params, timeout=60)
    response.raise_for_status()

    return response.json()


def extract_metrics(pagespeed_data, strategy):
    """
    Extract relevant metrics from PageSpeed Insights response

    Args:
        pagespeed_data: Full API response
        strategy: 'desktop' or 'mobile'

    Returns:
        dict: Structured metrics
    """
    lighthouse = pagespeed_data['lighthouseResult']
    audits = lighthouse['audits']
    categories = lighthouse['categories']

    # Performance score (0-100)
    performance_score = round(categories['performance']['score'] * 100, 1)

    # Core Web Vitals
    metrics = {
        'strategy': strategy,
        'performance_score': performance_score,

        # Timing metrics (in milliseconds)
        'fcp': audits.get('first-contentful-paint', {}).get('numericValue', 0),
        'lcp': audits.get('largest-contentful-paint', {}).get('numericValue', 0),
        'tbt': audits.get('total-blocking-time', {}).get('numericValue', 0),
        'tti': audits.get('interactive', {}).get('numericValue', 0),
        'speed_index': audits.get('speed-index', {}).get('numericValue', 0),

        # Layout shift (score, not time)
        'cls': audits.get('cumulative-layout-shift', {}).get('numericValue', 0),

        # Additional category scores
        'accessibility_score': round(categories.get('accessibility', {}).get('score', 0) * 100, 1),
        'best_practices_score': round(categories.get('best-practices', {}).get('score', 0) * 100, 1),
        'seo_score': round(categories.get('seo', {}).get('score', 0) * 100, 1),
    }

    # Extract opportunities (things that can be improved)
    opportunities = []
    for audit_id, audit in audits.items():
        if audit.get('details', {}).get('type') == 'opportunity':
            # Only include if there's potential savings
            savings_ms = audit.get('numericValue', 0)
            if savings_ms > 0:
                opportunities.append({
                    'id': audit_id,
                    'title': audit.get('title', ''),
                    'description': audit.get('description', ''),
                    'savings_ms': round(savings_ms, 0),
                    'score': audit.get('score', 0)
                })

    # Sort by potential savings (highest first)
    opportunities.sort(key=lambda x: x['savings_ms'], reverse=True)
    metrics['opportunities'] = opportunities[:5]  # Top 5 opportunities

    # Extract diagnostics (informational items about performance)
    diagnostics = []
    for audit_id, audit in audits.items():
        if (audit.get('score') is not None and
            audit.get('score') < 1.0 and
            audit.get('scoreDisplayMode') == 'numeric' and
            audit.get('details', {}).get('type') != 'opportunity'):

            diagnostics.append({
                'id': audit_id,
                'title': audit.get('title', ''),
                'description': audit.get('description', ''),
                'score': round(audit.get('score', 0), 2),
                'display_value': audit.get('displayValue', '')
            })

    # Sort by score (lowest first - most problematic)
    diagnostics.sort(key=lambda x: x['score'])
    metrics['diagnostics'] = diagnostics[:5]  # Top 5 issues

    return metrics


def build_dynamodb_item(timestamp, url, desktop_metrics, mobile_metrics, commit_data):
    """
    Build DynamoDB item with all collected data

    Args:
        timestamp: ISO timestamp
        url: Tested URL
        desktop_metrics: Extracted desktop metrics
        mobile_metrics: Extracted mobile metrics
        commit_data: GitHub commit information

    Returns:
        dict: DynamoDB item ready for storage
    """
    # Convert all numeric values to Decimal for DynamoDB
    def convert_to_decimal(obj):
        if isinstance(obj, dict):
            return {k: convert_to_decimal(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [convert_to_decimal(v) for v in obj]
        elif isinstance(obj, float):
            return Decimal(str(obj))
        elif isinstance(obj, int):
            return Decimal(str(obj))
        return obj

    item = {
        # DynamoDB keys
        'pk': 'METRICS',
        'sk': timestamp,

        'timestamp': timestamp,
        'url': url,

        # Desktop metrics
        'desktop': convert_to_decimal(desktop_metrics),

        # Mobile metrics
        'mobile': convert_to_decimal(mobile_metrics),

        # Git commit correlation
        'commit': {
            'sha': commit_data['sha'],
            'short_sha': commit_data['short_sha'],
            'message': commit_data['message'],
            'author': commit_data['author'],
            'date': commit_data['date'],
            'url': commit_data['url']
        },

        # Computed fields for easy querying
        'desktop_score': convert_to_decimal(desktop_metrics['performance_score']),
        'mobile_score': convert_to_decimal(mobile_metrics['performance_score']),
        'average_score': convert_to_decimal(
            (desktop_metrics['performance_score'] + mobile_metrics['performance_score']) / 2
        )
    }

    return item


def store_metrics(table_name, item):
    """
    Store metrics in DynamoDB

    Args:
        table_name: DynamoDB table name
        item: Item to store
    """
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(table_name)

    table.put_item(Item=item)

    print(f"Stored item with timestamp: {item['timestamp']}")


def generate_pagespeed_report(commit_data, desktop_metrics, mobile_metrics, target_url, timestamp):
    """
    Generate a markdown report with PageSpeed Insights results

    Args:
        commit_data: GitHub commit information
        desktop_metrics: Desktop performance metrics
        mobile_metrics: Mobile performance metrics
        target_url: URL that was tested
        timestamp: When the test was run

    Returns:
        str: Markdown-formatted report
    """
    report = f"""# PageSpeed Insights Report

**URL**: {target_url}
**Commit**: [{commit_data['sha'][:7]}]({commit_data['url']})
**Date**: {timestamp}
**Message**: {commit_data['message']}
**Author**: {commit_data['author']}

## Performance Scores

| Category | Mobile | Desktop |
|----------|--------|---------|
| Performance | {mobile_metrics.get('performance_score', 0):.1f} | {desktop_metrics.get('performance_score', 0):.1f} |
| Accessibility | {mobile_metrics.get('accessibility_score', 0):.1f} | {desktop_metrics.get('accessibility_score', 0):.1f} |
| Best Practices | {mobile_metrics.get('best_practices_score', 0):.1f} | {desktop_metrics.get('best_practices_score', 0):.1f} |
| SEO | {mobile_metrics.get('seo_score', 0):.1f} | {desktop_metrics.get('seo_score', 0):.1f} |

## Core Web Vitals

### Mobile
| Metric | Value |
|--------|-------|
| First Contentful Paint (FCP) | {mobile_metrics.get('fcp', 0) / 1000:.2f}s |
| Largest Contentful Paint (LCP) | {mobile_metrics.get('lcp', 0) / 1000:.2f}s |
| Total Blocking Time (TBT) | {mobile_metrics.get('tbt', 0):.0f}ms |
| Cumulative Layout Shift (CLS) | {mobile_metrics.get('cls', 0):.3f} |
| Speed Index | {mobile_metrics.get('speed_index', 0) / 1000:.2f}s |

### Desktop
| Metric | Value |
|--------|-------|
| First Contentful Paint (FCP) | {desktop_metrics.get('fcp', 0) / 1000:.2f}s |
| Largest Contentful Paint (LCP) | {desktop_metrics.get('lcp', 0) / 1000:.2f}s |
| Total Blocking Time (TBT) | {desktop_metrics.get('tbt', 0):.0f}ms |
| Cumulative Layout Shift (CLS) | {desktop_metrics.get('cls', 0):.3f} |
| Speed Index | {desktop_metrics.get('speed_index', 0) / 1000:.2f}s |

"""

    # Add Mobile Opportunities
    if mobile_metrics.get('opportunities'):
        report += "## Mobile Optimization Opportunities\n\n"
        for opp in mobile_metrics['opportunities']:
            report += f"### {opp['title']}\n"
            report += f"**Potential Savings**: {opp['savings_ms'] / 1000:.2f}s\n\n"
            if opp.get('description'):
                report += f"{opp['description']}\n\n"

    # Add Desktop Opportunities
    if desktop_metrics.get('opportunities'):
        report += "## Desktop Optimization Opportunities\n\n"
        for opp in desktop_metrics['opportunities']:
            report += f"### {opp['title']}\n"
            report += f"**Potential Savings**: {opp['savings_ms'] / 1000:.2f}s\n\n"
            if opp.get('description'):
                report += f"{opp['description']}\n\n"

    report += "\n---\n*Generated by PageSpeed Insights Lambda Collector*\n"

    return report


def commit_file_to_repo(repo, token, file_path, content, commit_message, branch='main'):
    """
    Commit a file to GitHub repository

    Args:
        repo: Repository in format 'owner/repo'
        token: GitHub personal access token
        file_path: Path within the repo where file should be created
        content: File content
        commit_message: Commit message
        branch: Branch to commit to (default: main)
    """
    import base64

    headers = {
        'Authorization': f'token {token}',
        'Accept': 'application/vnd.github.v3+json'
    }

    # Check if file already exists
    check_url = f'https://api.github.com/repos/{repo}/contents/{file_path}'
    params = {'ref': branch}
    check_response = requests.get(check_url, headers=headers, params=params)

    sha = None
    if check_response.status_code == 200:
        sha = check_response.json()['sha']

    # Prepare file content
    content_bytes = content.encode('utf-8')
    content_base64 = base64.b64encode(content_bytes).decode('utf-8')

    # Create or update file
    update_data = {
        'message': commit_message,
        'content': content_base64,
        'branch': branch
    }

    if sha:
        update_data['sha'] = sha

    response = requests.put(check_url, headers=headers, json=update_data)
    response.raise_for_status()

    print(f"Committed file to {repo}/{file_path}")
    return response.json()

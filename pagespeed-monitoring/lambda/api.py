"""
PageSpeed Insights API Lambda

Serves historical PageSpeed metrics data via API Gateway
for visualization on the website.
"""

import boto3
import json
import os
from decimal import Decimal
from boto3.dynamodb.conditions import Key


class DecimalEncoder(json.JSONEncoder):
    """Custom JSON encoder for DynamoDB Decimal types"""
    def default(self, obj):
        if isinstance(obj, Decimal):
            # Convert to int if it's a whole number, otherwise float
            if obj % 1 == 0:
                return int(obj)
            return float(obj)
        return super().default(obj)


def lambda_handler(event, context):
    """
    API Gateway Lambda handler

    Supports multiple endpoints:
    - GET /metrics - Get all historical metrics
    - GET /metrics/latest - Get most recent metrics
    - GET /metrics/summary - Get summary statistics

    Query Parameters:
        limit: Maximum number of records to return (default: 100)
        device: Filter by 'desktop' or 'mobile'
    """

    table_name = os.environ.get('DYNAMODB_TABLE', 'pagespeed-metrics')
    # API Gateway HTTP API uses 'rawPath', REST API uses 'path'
    path = event.get('rawPath') or event.get('path', '/metrics')
    query_params = event.get('queryStringParameters') or {}

    try:
        # Route to appropriate handler
        if path.endswith('/latest'):
            data = get_latest_metrics(table_name)
        elif path.endswith('/summary'):
            data = get_summary(table_name)
        else:
            limit = int(query_params.get('limit', 100))
            data = get_all_metrics(table_name, limit)

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',  # Update with your domain
                'Access-Control-Allow-Methods': 'GET, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Cache-Control': 'public, max-age=300'  # Cache for 5 minutes
            },
            'body': json.dumps(data, cls=DecimalEncoder)
        }

    except Exception as e:
        print(f"Error retrieving metrics: {str(e)}")
        import traceback
        traceback.print_exc()

        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': 'Failed to retrieve metrics',
                'message': str(e)
            })
        }


def get_all_metrics(table_name, limit=100):
    """
    Retrieve all historical metrics, sorted by timestamp

    Args:
        table_name: DynamoDB table name
        limit: Maximum records to return

    Returns:
        list: All metrics sorted chronologically
    """
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(table_name)

    # Scan table and get all items
    response = table.scan(Limit=limit)
    items = response.get('Items', [])

    # Handle pagination if needed
    while 'LastEvaluatedKey' in response and len(items) < limit:
        response = table.scan(
            ExclusiveStartKey=response['LastEvaluatedKey'],
            Limit=limit - len(items)
        )
        items.extend(response.get('Items', []))

    # Sort by timestamp (oldest to newest)
    items.sort(key=lambda x: x['timestamp'])

    return {
        'count': len(items),
        'metrics': items
    }


def get_latest_metrics(table_name):
    """
    Retrieve only the most recent metrics

    Args:
        table_name: DynamoDB table name

    Returns:
        dict: Latest metrics record
    """
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(table_name)

    # Scan and get all items (we need to scan to find latest)
    response = table.scan()
    items = response.get('Items', [])

    if not items:
        return {
            'message': 'No metrics available yet'
        }

    # Find the most recent item
    latest = max(items, key=lambda x: x['timestamp'])

    return {
        'latest': latest
    }


def get_summary(table_name):
    """
    Generate summary statistics from historical data

    Args:
        table_name: DynamoDB table name

    Returns:
        dict: Summary statistics including trends and averages
    """
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(table_name)

    response = table.scan()
    items = response.get('Items', [])

    if not items:
        return {
            'message': 'No metrics available yet'
        }

    # Sort by timestamp
    items.sort(key=lambda x: x['timestamp'])

    # Calculate statistics
    desktop_scores = [float(item['desktop_score']) for item in items]
    mobile_scores = [float(item['mobile_score']) for item in items]
    average_scores = [float(item['average_score']) for item in items]

    latest = items[-1]
    oldest = items[0]

    # Calculate trends
    desktop_trend = desktop_scores[-1] - desktop_scores[0] if len(desktop_scores) > 1 else 0
    mobile_trend = mobile_scores[-1] - mobile_scores[0] if len(mobile_scores) > 1 else 0

    # Get latest opportunities and diagnostics
    desktop_opportunities = latest.get('desktop', {}).get('opportunities', [])
    mobile_opportunities = latest.get('mobile', {}).get('opportunities', [])

    summary = {
        'total_measurements': len(items),
        'date_range': {
            'start': oldest['timestamp'],
            'end': latest['timestamp']
        },

        'current': {
            'desktop_score': latest['desktop_score'],
            'mobile_score': latest['mobile_score'],
            'average_score': latest['average_score'],
            'commit': latest['commit']
        },

        'statistics': {
            'desktop': {
                'current': desktop_scores[-1],
                'average': round(sum(desktop_scores) / len(desktop_scores), 1),
                'min': min(desktop_scores),
                'max': max(desktop_scores),
                'trend': round(desktop_trend, 1)
            },
            'mobile': {
                'current': mobile_scores[-1],
                'average': round(sum(mobile_scores) / len(mobile_scores), 1),
                'min': min(mobile_scores),
                'max': max(mobile_scores),
                'trend': round(mobile_trend, 1)
            }
        },

        'top_opportunities': {
            'desktop': desktop_opportunities[:3],
            'mobile': mobile_opportunities[:3]
        },

        'historical_data': [
            {
                'timestamp': item['timestamp'],
                'desktop_score': item['desktop_score'],
                'mobile_score': item['mobile_score'],
                'commit_sha': item['commit']['short_sha']
            }
            for item in items
        ]
    }

    return summary


def options_handler(event, context):
    """
    Handle CORS preflight requests

    Returns:
        dict: CORS headers for OPTIONS request
    """
    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Max-Age': '3600'
        },
        'body': ''
    }

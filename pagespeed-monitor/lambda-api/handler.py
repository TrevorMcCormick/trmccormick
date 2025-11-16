import json
import os
import boto3
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')

class DecimalEncoder(json.JSONEncoder):
    """Helper to convert Decimal to float for JSON serialization"""
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def handler(event, context):
    """
    API endpoint to retrieve performance metrics from DynamoDB.
    Returns all metrics sorted by timestamp.
    """

    table_name = os.environ.get('DYNAMODB_TABLE')

    if not table_name:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': 'Missing configuration'})
        }

    try:
        table = dynamodb.Table(table_name)

        # Scan the table (for production, consider using Query with GSI)
        response = table.scan()
        items = response.get('Items', [])

        # Continue scanning if there are more items
        while 'LastEvaluatedKey' in response:
            response = table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            items.extend(response.get('Items', []))

        # Convert all timestamps to strings and sort (most recent first)
        for item in items:
            ts = item.get('timestamp', '')
            if isinstance(ts, Decimal):
                item['timestamp'] = str(ts)
            elif not isinstance(ts, str):
                item['timestamp'] = str(ts) if ts else ''

        items.sort(key=lambda x: x.get('timestamp', ''), reverse=True)

        # Format for frontend
        metrics = []
        for item in items:
            metrics.append({
                'timestamp': item.get('timestamp'),
                'commit': item.get('commit', {}),
                'url': item.get('url'),
                'mobile': item.get('mobile'),
                'desktop': item.get('desktop')
            })

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Cache-Control': 'max-age=300'  # Cache for 5 minutes
            },
            'body': json.dumps({
                'metrics': metrics,
                'count': len(metrics)
            }, cls=DecimalEncoder)
        }

    except Exception as e:
        print(f'Error retrieving metrics: {str(e)}')
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': 'Failed to retrieve metrics'})
        }

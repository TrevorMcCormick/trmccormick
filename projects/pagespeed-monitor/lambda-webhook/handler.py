import json
import hmac
import hashlib
import os
import boto3

lambda_client = boto3.client('lambda')

def verify_github_signature(payload_body, signature_header, secret):
    """Verify that the webhook actually came from GitHub"""
    if not signature_header:
        return False

    # GitHub sends signature as "sha256=<hash>"
    hash_algorithm, github_signature = signature_header.split('=')

    # Compute HMAC
    mac = hmac.new(
        secret.encode('utf-8'),
        msg=payload_body.encode('utf-8'),
        digestmod=hashlib.sha256
    )
    expected_signature = mac.hexdigest()

    # Constant-time comparison to prevent timing attacks
    return hmac.compare_digest(expected_signature, github_signature)

def handler(event, context):
    """
    Handle GitHub webhook POST requests.
    Validates the webhook signature and triggers the collector Lambda.
    """

    # Get webhook secret from environment
    webhook_secret = os.environ.get('GITHUB_WEBHOOK_SECRET')
    collector_function = os.environ.get('COLLECTOR_FUNCTION_ARN')

    if not webhook_secret or not collector_function:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Missing configuration'})
        }

    # Verify GitHub signature
    # API Gateway HTTP API converts all headers to lowercase
    headers = event.get('headers', {})
    signature = headers.get('x-hub-signature-256') or headers.get('X-Hub-Signature-256')
    body = event.get('body', '{}')

    # Debug logging
    print(f"Signature header: {signature}")
    print(f"Body length: {len(body)}")
    print(f"Body (first 100 chars): {body[:100]}")

    if not verify_github_signature(body, signature, webhook_secret):
        print('Invalid webhook signature')
        # Log computed signature for debugging
        if signature and signature.startswith('sha256='):
            mac = hmac.new(
                webhook_secret.encode('utf-8'),
                msg=body.encode('utf-8'),
                digestmod=hashlib.sha256
            )
            computed = mac.hexdigest()
            print(f"Expected signature: sha256={computed}")
            print(f"Received signature: {signature}")
        return {
            'statusCode': 403,
            'body': json.dumps({'error': 'Invalid signature'})
        }

    # Parse webhook payload
    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid JSON'})
        }

    # Only process push events to main branch
    # API Gateway HTTP API converts all headers to lowercase
    github_event = headers.get('x-github-event') or headers.get('X-GitHub-Event')
    if github_event != 'push':
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Event type not supported'})
        }

    ref = payload.get('ref', '')
    if not ref.endswith('/main') and not ref.endswith('/master'):
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Not main/master branch'})
        }

    # Extract commit information
    head_commit = payload.get('head_commit', {})
    commit_data = {
        'sha': head_commit.get('id'),
        'message': head_commit.get('message'),
        'author': head_commit.get('author', {}).get('name'),
        'timestamp': head_commit.get('timestamp'),
        'url': head_commit.get('url')
    }

    print(f"Processing commit: {commit_data['sha'][:7]} - {commit_data['message']}")

    # Invoke collector Lambda asynchronously
    try:
        lambda_client.invoke(
            FunctionName=collector_function,
            InvocationType='Event',  # Async invocation
            Payload=json.dumps(commit_data)
        )

        return {
            'statusCode': 202,
            'body': json.dumps({
                'message': 'Accepted',
                'commit': commit_data['sha'][:7]
            })
        }
    except Exception as e:
        print(f"Error invoking collector: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to trigger collector'})
        }

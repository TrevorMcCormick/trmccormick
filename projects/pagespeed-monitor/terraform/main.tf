terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# DynamoDB Table for storing metrics
resource "aws_dynamodb_table" "metrics" {
  name           = "${var.project_name}-metrics"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "pk"
  range_key      = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-metrics"
    Environment = var.environment
  }
}

# SNS Topic for PageSpeed alerts
resource "aws_sns_topic" "pagespeed_alerts" {
  name = "${var.project_name}-alerts"

  tags = {
    Name        = "${var.project_name}-alerts"
    Environment = var.environment
  }
}

# SNS Email subscription (requires manual confirmation)
resource "aws_sns_topic_subscription" "email_alerts" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.pagespeed_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# IAM Role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for Lambda functions
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.metrics.arn
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.pagespeed_alerts.arn
      }
    ]
  })
}

# Lambda function: Webhook Handler
data "archive_file" "webhook_lambda" {
  type        = "zip"
  source_file = "../lambda-webhook/handler.py"
  output_path = "../lambda-webhook/function.zip"
}

resource "aws_lambda_function" "webhook" {
  filename         = data.archive_file.webhook_lambda.output_path
  function_name    = "${var.project_name}-webhook"
  role            = aws_iam_role.lambda_role.arn
  handler         = "handler.handler"
  source_code_hash = data.archive_file.webhook_lambda.output_base64sha256
  runtime         = "python3.11"
  timeout         = 30

  environment {
    variables = {
      GITHUB_WEBHOOK_SECRET = var.github_webhook_secret
      COLLECTOR_FUNCTION_ARN = aws_lambda_function.collector.arn
    }
  }

  tags = {
    Name = "${var.project_name}-webhook"
  }
}

# Lambda function: Collector
data "archive_file" "collector_lambda" {
  type        = "zip"
  source_file = "../lambda-collector/handler.py"
  output_path = "../lambda-collector/function.zip"
}

resource "aws_lambda_function" "collector" {
  filename         = data.archive_file.collector_lambda.output_path
  function_name    = "${var.project_name}-collector"
  role            = aws_iam_role.lambda_role.arn
  handler         = "handler.handler"
  source_code_hash = data.archive_file.collector_lambda.output_base64sha256
  runtime         = "python3.11"
  timeout         = 60

  environment {
    variables = {
      DYNAMODB_TABLE    = aws_dynamodb_table.metrics.name
      TARGET_URL        = var.target_url
      PAGESPEED_API_KEY = var.pagespeed_api_key
      GITHUB_TOKEN      = var.github_token
      GITHUB_REPO       = var.github_repo
      SNS_TOPIC_ARN     = aws_sns_topic.pagespeed_alerts.arn
      ALERT_THRESHOLD   = var.alert_threshold
    }
  }

  tags = {
    Name = "${var.project_name}-collector"
  }
}

# Lambda function: API Handler
data "archive_file" "api_lambda" {
  type        = "zip"
  source_file = "../lambda-api/handler.py"
  output_path = "../lambda-api/function.zip"
}

resource "aws_lambda_function" "api" {
  filename         = data.archive_file.api_lambda.output_path
  function_name    = "${var.project_name}-api"
  role            = aws_iam_role.lambda_role.arn
  handler         = "handler.handler"
  source_code_hash = data.archive_file.api_lambda.output_base64sha256
  runtime         = "python3.11"
  timeout         = 30

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.metrics.name
    }
  }

  tags = {
    Name = "${var.project_name}-api"
  }
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["Content-Type", "X-Hub-Signature-256", "X-GitHub-Event"]
    max_age       = 300
  }
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "prod"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }
}

resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = 7
}

# API Gateway Integration: Webhook
resource "aws_apigatewayv2_integration" "webhook" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.webhook.invoke_arn
}

resource "aws_apigatewayv2_route" "webhook" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /webhook"
  target    = "integrations/${aws_apigatewayv2_integration.webhook.id}"
}

# API Gateway Integration: Metrics API
resource "aws_apigatewayv2_integration" "api" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.api.invoke_arn
}

resource "aws_apigatewayv2_route" "metrics" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /metrics"
  target    = "integrations/${aws_apigatewayv2_integration.api.id}"
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "webhook_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# Outputs
output "webhook_url" {
  description = "GitHub webhook URL"
  value       = "${aws_apigatewayv2_api.main.api_endpoint}/prod/webhook"
}

output "metrics_api_url" {
  description = "Metrics API endpoint"
  value       = "${aws_apigatewayv2_api.main.api_endpoint}/prod/metrics"
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.metrics.name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for PageSpeed alerts"
  value       = aws_sns_topic.pagespeed_alerts.arn
}

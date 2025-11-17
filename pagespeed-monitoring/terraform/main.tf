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

  default_tags {
    tags = {
      Project     = "PageSpeed Monitoring"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ============================================================================
# DynamoDB Table for storing PageSpeed metrics
# ============================================================================

resource "aws_dynamodb_table" "pagespeed_metrics" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"  # On-demand pricing for low-volume workload

  # Partition key
  hash_key = "timestamp"

  # Sort key
  range_key = "url"

  attribute {
    name = "timestamp"
    type = "S"  # String (ISO format)
  }

  attribute {
    name = "url"
    type = "S"  # String (website URL)
  }

  # Enable point-in-time recovery for data protection
  point_in_time_recovery {
    enabled = true
  }

  # Enable encryption at rest
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "PageSpeed Metrics Storage"
  }
}

# ============================================================================
# IAM Roles and Policies
# ============================================================================

# IAM role for the collector Lambda
resource "aws_iam_role" "collector_lambda_role" {
  name = "${var.project_name}-collector-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM role for the API Lambda
resource "aws_iam_role" "api_lambda_role" {
  name = "${var.project_name}-api-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Policy for collector Lambda to write to DynamoDB
resource "aws_iam_role_policy" "collector_dynamodb_policy" {
  name = "dynamodb-write-access"
  role = aws_iam_role.collector_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.pagespeed_metrics.arn
      }
    ]
  })
}

# Policy for API Lambda to read from DynamoDB
resource "aws_iam_role_policy" "api_dynamodb_policy" {
  name = "dynamodb-read-access"
  role = aws_iam_role.api_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:GetItem"
        ]
        Resource = aws_dynamodb_table.pagespeed_metrics.arn
      }
    ]
  })
}

# Attach CloudWatch Logs policy to both Lambda roles
resource "aws_iam_role_policy_attachment" "collector_logs" {
  role       = aws_iam_role.collector_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "api_logs" {
  role       = aws_iam_role.api_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ============================================================================
# Lambda Functions
# ============================================================================

# Package the collector Lambda function
# Note: Run ../scripts/build-lambda.sh first to create the build directory with dependencies
data "archive_file" "collector_lambda_package" {
  type        = "zip"
  source_dir  = "${path.module}/../build"
  output_path = "${path.module}/collector_lambda.zip"
  excludes = [
    "__pycache__",
    "*.pyc",
    ".DS_Store",
    "*.dist-info",
    "*.egg-info"
  ]
}

# Collector Lambda function
resource "aws_lambda_function" "collector" {
  filename         = data.archive_file.collector_lambda_package.output_path
  function_name    = "${var.project_name}-collector"
  role            = aws_iam_role.collector_lambda_role.arn
  handler         = "collector.lambda_handler"
  source_code_hash = data.archive_file.collector_lambda_package.output_base64sha256
  runtime         = "python3.11"
  timeout         = 60  # 1 minute (PageSpeed API can be slow)
  memory_size     = 256

  environment {
    variables = {
      DYNAMODB_TABLE    = aws_dynamodb_table.pagespeed_metrics.name
      TARGET_URL        = var.target_website_url
      GITHUB_REPO       = var.github_repo
      PAGESPEED_API_KEY = var.pagespeed_api_key
      GITHUB_TOKEN      = var.github_token
    }
  }

  depends_on = [
    aws_iam_role_policy.collector_dynamodb_policy,
    aws_iam_role_policy_attachment.collector_logs
  ]
}

# API Lambda function
resource "aws_lambda_function" "api" {
  filename         = data.archive_file.collector_lambda_package.output_path
  function_name    = "${var.project_name}-api"
  role            = aws_iam_role.api_lambda_role.arn
  handler         = "api.lambda_handler"
  source_code_hash = data.archive_file.collector_lambda_package.output_base64sha256
  runtime         = "python3.11"
  timeout         = 10
  memory_size     = 128

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.pagespeed_metrics.name
    }
  }

  depends_on = [
    aws_iam_role_policy.api_dynamodb_policy,
    aws_iam_role_policy_attachment.api_logs
  ]
}

# ============================================================================
# EventBridge Rule for Scheduled Trigger (Optional - disabled by default)
# PageSpeed checks are triggered from CodeBuild after deployments
# Set enable_scheduled_checks = true to also run on a schedule
# ============================================================================

resource "aws_cloudwatch_event_rule" "weekly_pagespeed_check" {
  count = var.enable_scheduled_checks ? 1 : 0

  name                = "${var.project_name}-weekly-check"
  description         = "Trigger PageSpeed check on schedule: ${var.schedule_expression}"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "collector_lambda" {
  count = var.enable_scheduled_checks ? 1 : 0

  rule      = aws_cloudwatch_event_rule.weekly_pagespeed_check[0].name
  target_id = "PageSpeedCollector"
  arn       = aws_lambda_function.collector.arn
}

# Grant EventBridge permission to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  count = var.enable_scheduled_checks ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.collector.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.weekly_pagespeed_check[0].arn
}

# ============================================================================
# API Gateway
# ============================================================================

resource "aws_apigatewayv2_api" "pagespeed_api" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
  description   = "PageSpeed Metrics API"

  cors_configuration {
    allow_origins = var.cors_allowed_origins
    allow_methods = ["GET", "OPTIONS"]
    allow_headers = ["Content-Type"]
    max_age       = 3600
  }
}

# API Gateway integration with Lambda
resource "aws_apigatewayv2_integration" "api_lambda" {
  api_id           = aws_apigatewayv2_api.pagespeed_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.api.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

# API Gateway routes
resource "aws_apigatewayv2_route" "metrics" {
  api_id    = aws_apigatewayv2_api.pagespeed_api.id
  route_key = "GET /metrics"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "metrics_latest" {
  api_id    = aws_apigatewayv2_api.pagespeed_api.id
  route_key = "GET /metrics/latest"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

resource "aws_apigatewayv2_route" "metrics_summary" {
  api_id    = aws_apigatewayv2_api.pagespeed_api.id
  route_key = "GET /metrics/summary"
  target    = "integrations/${aws_apigatewayv2_integration.api_lambda.id}"
}

# API Gateway stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.pagespeed_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
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

# CloudWatch log group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.project_name}"
  retention_in_days = 7
}

# Grant API Gateway permission to invoke Lambda
resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.pagespeed_api.execution_arn}/*/*"
}

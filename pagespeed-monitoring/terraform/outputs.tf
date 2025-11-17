output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.pagespeed_metrics.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.pagespeed_metrics.arn
}

output "collector_lambda_arn" {
  description = "ARN of the collector Lambda function"
  value       = aws_lambda_function.collector.arn
}

output "collector_lambda_name" {
  description = "Name of the collector Lambda function"
  value       = aws_lambda_function.collector.function_name
}

output "api_lambda_arn" {
  description = "ARN of the API Lambda function"
  value       = aws_lambda_function.api.arn
}

output "api_lambda_name" {
  description = "Name of the API Lambda function"
  value       = aws_lambda_function.api.function_name
}

output "api_gateway_url" {
  description = "URL of the API Gateway endpoint"
  value       = aws_apigatewayv2_api.pagespeed_api.api_endpoint
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_apigatewayv2_api.pagespeed_api.id
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule (only if scheduled checks enabled)"
  value       = var.enable_scheduled_checks ? aws_cloudwatch_event_rule.weekly_pagespeed_check[0].arn : "Scheduled checks disabled - triggered from CodeBuild"
}

output "test_collector_command" {
  description = "Command to manually trigger the collector Lambda for testing"
  value       = "aws lambda invoke --function-name ${aws_lambda_function.collector.function_name} --region ${var.aws_region} /tmp/response.json && cat /tmp/response.json"
}

output "api_endpoints" {
  description = "Available API endpoints"
  value = {
    all_metrics = "${aws_apigatewayv2_api.pagespeed_api.api_endpoint}/metrics"
    latest      = "${aws_apigatewayv2_api.pagespeed_api.api_endpoint}/metrics/latest"
    summary     = "${aws_apigatewayv2_api.pagespeed_api.api_endpoint}/metrics/summary"
  }
}

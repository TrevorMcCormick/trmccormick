variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "pagespeed-monitor"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for storing metrics"
  type        = string
  default     = "pagespeed-metrics"
}

variable "target_website_url" {
  description = "Website URL to monitor"
  type        = string
  default     = "https://trmccormick.com"
}

variable "github_repo" {
  description = "GitHub repository in format 'owner/repo'"
  type        = string
  default     = "yourusername/trmccormick"  # Update this
}

variable "pagespeed_api_key" {
  description = "Google PageSpeed Insights API key"
  type        = string
  sensitive   = true
  default     = ""  # Set via environment variable or terraform.tfvars
}

variable "github_token" {
  description = "GitHub personal access token (optional)"
  type        = string
  sensitive   = true
  default     = ""  # Optional, set if needed for private repos
}

variable "enable_scheduled_checks" {
  description = "Enable automatic scheduled PageSpeed checks via EventBridge (disabled by default - triggered from CodeBuild)"
  type        = bool
  default     = false
}

variable "schedule_expression" {
  description = "EventBridge schedule expression for PageSpeed checks (only used if enable_scheduled_checks = true)"
  type        = string
  default     = "cron(0 12 ? * MON *)"  # Every Monday at noon UTC
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["https://trmccormick.com", "http://localhost:1313"]
}

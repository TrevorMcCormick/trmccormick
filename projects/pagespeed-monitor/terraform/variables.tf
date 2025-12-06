variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "pagespeed-monitor"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "target_url" {
  description = "Website URL to monitor"
  type        = string
  default     = "https://trmccormick.com"
}

variable "github_webhook_secret" {
  description = "Secret token for GitHub webhook validation"
  type        = string
  sensitive   = true
}

variable "pagespeed_api_key" {
  description = "Google PageSpeed Insights API key (optional but recommended)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_token" {
  description = "GitHub personal access token for committing reports (requires repo write permissions)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_repo" {
  description = "GitHub repository in format 'owner/repo' (e.g., 'trmccormick/trmccormick')"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email address to receive PageSpeed alerts"
  type        = string
  default     = ""
}

variable "alert_threshold" {
  description = "Score drop threshold (in points) to trigger alerts"
  type        = number
  default     = 5
}

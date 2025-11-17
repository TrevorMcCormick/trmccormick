# ============================================================================
# IAM Policy for CodeBuild to Invoke PageSpeed Collector Lambda
#
# IMPORTANT: You need to attach this policy to your existing CodeBuild role
#
# To find your CodeBuild role:
#   aws codebuild batch-get-projects --names YOUR_PROJECT_NAME \
#     --query 'projects[0].serviceRole' --output text
#
# To attach this policy (after terraform apply):
#   aws iam attach-role-policy \
#     --role-name YOUR_CODEBUILD_ROLE_NAME \
#     --policy-arn $(terraform output -raw codebuild_lambda_invoke_policy_arn)
# ============================================================================

# Create the policy document
data "aws_iam_policy_document" "codebuild_lambda_invoke" {
  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      aws_lambda_function.collector.arn
    ]
  }
}

# Create the managed policy
resource "aws_iam_policy" "codebuild_lambda_invoke" {
  name        = "${var.project_name}-codebuild-lambda-invoke"
  description = "Allows CodeBuild to invoke PageSpeed collector Lambda"
  policy      = data.aws_iam_policy_document.codebuild_lambda_invoke.json

  tags = {
    Name    = "CodeBuild Lambda Invoke Policy"
    Purpose = "PageSpeed Monitoring"
  }
}

# Output the policy ARN for easy attachment
output "codebuild_lambda_invoke_policy_arn" {
  description = "ARN of the IAM policy for CodeBuild to invoke the PageSpeed Lambda"
  value       = aws_iam_policy.codebuild_lambda_invoke.arn
}

output "codebuild_policy_attach_command" {
  description = "Command to attach this policy to your CodeBuild role"
  value       = "aws iam attach-role-policy --role-name YOUR_CODEBUILD_ROLE_NAME --policy-arn ${aws_iam_policy.codebuild_lambda_invoke.arn}"
}

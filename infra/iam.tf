/*
  Create user role for lambda function
*/
data "aws_iam_policy_document" "lambda_assume_role_policy_document" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "lambda-lambdaRole-waf"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy_document.json
}

data "aws_iam_policy_document" "lambda_role_policy_document" {
  statement {
    effect = "Allow"

    actions = [
      "s3:Get*",
      "s3:List*",
      "s3:Put*",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "dynamodb:*",
      "lambda:GetLayerVersion"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_waf_policy" {
  name   = "lambda-waf-policy"
  policy = data.aws_iam_policy_document.lambda_role_policy_document.json
  role   = aws_iam_role.lambda_role.id
}

resource "aws_iam_policy" "lambda_logging_policy" {
  name = "lambda-logging-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect : "Allow",
        Resource : "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logging_policy_attachment" {
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
  role       = aws_iam_role.lambda_role.id
}

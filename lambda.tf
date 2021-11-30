provider "aws" {
  region = "eu-west-1"
}



resource "aws_iam_role" "lambda_role" {
 name   = "iam_role_lambda_function"
 assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# IAM policy for logging from a lambda and access to S3

resource "aws_iam_policy" "lambda_logging" {

  name         = "iam_policy_lambda_1"
  path         = "/"
  description  = "IAM policy for new lambda"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {

        "Action" : [
          "s3:GetObject",
          "s3:PutObject"
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:s3:::*"
      }
    ]
  })
}

# Policy Attachment on the role.

resource "aws_iam_role_policy_attachment" "policy_attach" {
  role        = aws_iam_role.lambda_role.name
  policy_arn  = aws_iam_policy.lambda_logging.arn
}

#creation of lambda function

resource "aws_lambda_function" "lambda_new" {
  s3_bucket                      = "bucketoftarek8786"
  s3_key                         = "pet-exo.zip"
  function_name                  = "lambda-pet-2"
  handler                        = "lambda.lambda_handler"
  role                           = aws_iam_role.lambda_role.arn
  runtime                        = "python3.9"
  depends_on                     = [aws_iam_role_policy_attachment.policy_attach]
}


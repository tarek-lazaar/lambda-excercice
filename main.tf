provider "aws" {
  region = "eu-west-1"
}

terraform {

  backend "s3" {
    bucket         = "bucketoftarek8786"
    key            = "terraform.tfstates"
    dynamodb_table = "terraform-lock"
  }
}


resource "aws_iam_role" "lambda_role" {
  name               = "iam_role_lambda_function"
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

  name        = "iam_policy_lambda_1"
  path        = "/"
  description = "IAM policy for new lambda"
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
      },
      {
        "Sid" : "SpecificTable",
        "Effect" : "Allow",
        "Action" : [
          "dynamodb:BatchGet*",
          "dynamodb:DescribeStream",
          "dynamodb:DescribeTable",
          "dynamodb:Get*",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchWrite*",
          "dynamodb:CreateTable",
          "dynamodb:Delete*",
          "dynamodb:Update*",
          "dynamodb:PutItem"
        ],
        "Resource" : "arn:aws:dynamodb:*:*:table/Images"
      }
    ]
  })
}

# Policy Attachment on the role.

resource "aws_iam_role_policy_attachment" "policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

#creation of lambda function
data "archive_file" "image_script" {
  type        = "zip"
  source_file = "${path.module}/files/${var.script_filename}.py"  # SOURCE OF THE FILE
  output_path = "${path.module}/files/${var.script_filename}.zip" # DESTINATION OF THE GENERATED FILE (.zip)
}


resource "aws_lambda_function" "lambdaNew" {
  filename         = data.archive_file.image_script.output_path
  function_name    = var.script_filename
  handler          = "${var.script_filename}.lambda_handler"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.8"
  source_code_hash = data.archive_file.image_script.output_base64sha256

}
#create cloud watch rule with S3 source event

resource "aws_cloudwatch_event_rule" "rule1" {
  name        = "new-upload-s3"
  description = "Detect new uploaded files"

  event_pattern = <<EOF
{
  "source": ["aws.s3"],
  "detail-type": ["AWS API Call via CloudTrail"],
  "detail": {
    "eventSource": ["s3.amazonaws.com"],
    "eventName": ["PutObject"],
    "requestParameters": {
      "bucketName": ["bucketoftarek8786"]
    }
  }
}
EOF
}

#Notify sns topic

resource "aws_cloudwatch_event_target" "sns" {
  rule      = aws_cloudwatch_event_rule.rule1.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.event_upload.arn
}

#create sns topic
resource "aws_sns_topic" "event_upload" {
  name = "upload-to-s3"
}

#sns topic policy
resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.event_upload.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}


data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    resources = [aws_sns_topic.event_upload.arn]

  }
}

# Subscribe lambda to SNS topic
resource "aws_sns_topic_subscription" "invoke_with_sns" {
  topic_arn = aws_sns_topic.event_upload.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.lambdaNew.arn
}


#allow notification coming from sns to lambda

resource "aws_lambda_permission" "with_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambdaNew.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.event_upload.arn
}
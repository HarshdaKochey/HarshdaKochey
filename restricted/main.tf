resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Effect = "Allow",
    }]
  })
}

resource "aws_iam_policy" "lambda_s3_dynamodb_policy" {
  name        = "lambda_s3_dynamodb_policy"
  description = "Allows Lambda to read from S3, write to S3 and write to DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        Effect = "Allow",
        Resource = [
          "${aws_s3_bucket.source_bucket.arn}/*",
          "${aws_s3_bucket.destination_bucket.arn}/*"
        ]
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ],
        Effect = "Allow",
        Resource = "${aws_dynamodb_table.example.arn}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_dynamodb_attachment" {
  policy_arn = aws_iam_policy.lambda_s3_dynamodb_policy.arn
  role       = aws_iam_role.lambda_role.name
}


# Create a role for the webapp

resource "aws_iam_role" "webapp_role" {
  name = "webapp_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Effect = "Allow",
      },
    ],
  })
}

# Attach the Cognito permissions to the webapp role

resource "aws_iam_role_policy" "webapp_cognito_policy" {
  name = "webapp_cognito_policy"
  role = aws_iam_role.webapp_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cognito-idp:InitiateAuth",
          "cognito-idp:RespondToAuthChallenge",
          "cognito-idp:SignUp",
          "cognito-idp:ConfirmSignUp"
        ],
        Resource = "*"
      }
    ]
  })
}

# Create a role for the microservice

resource "aws_iam_role" "microservice_role" {
  name = "microservice_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Effect = "Allow",
      },
    ],
  })
}

# Attach the API Gateway permissions to the microservice role

resource "aws_iam_role_policy" "microservice_api_gateway_policy" {
  name = "microservice_api_gateway_policy"
  role = aws_iam_role.microservice_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "execute-api:Invoke"
        ],
        Resource = "*"
      }
    ]
  })
}
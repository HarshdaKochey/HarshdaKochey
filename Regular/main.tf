resource "aws_kms_key" "s3_key" {
  description = "KMS key for S3 bucket"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "key-default-1",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.aws_account_id}:my_iam_user"
      },
      "Action": "kms:*",
      "Resource": "*"
    }
  ]
}
POLICY
}

# Create S3 buckets for file upload and processed files

resource "aws_s3_bucket" "file_upload_bucket" {
  bucket = "my-file-upload-bucket"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.s3_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}


resource "aws_s3_bucket" "processed_files_bucket" {
  bucket = "my-processed-files-bucket"
  acl    = "private"

  lifecycle_rule {
    id      = "myrule"
    enabled = true

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 90
    }
  }    

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.my_kms_key.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}


# Create CloudFront distribution for content delivery

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.processed_files_bucket.bucket_regional_domain_name
    origin_id   = "S3Origin"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "S3 bucket content distribution"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3Origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI for S3 bucket content access"
}

# Create Lambda function for processing files

resource "aws_lambda_function" "file_processor" {
  filename      = "file_processor.zip"
  function_name = "file_processor"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_handler"
  runtime       = "python3.8"
  source_code_hash = filebase64sha256("file_processor.zip")
}

resource "aws_lambda_permission" "s3_trigger_permission" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.file_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.file_upload_bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.file_upload_bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.file_processor.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

# DynamoDB table for storing file metadata
resource "aws_dynamodb_table" "file_metadata" {
  name           = "fileMetadata"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# Cognito user pool for user authentication
resource "aws_cognito_user_pool" "main" {
  name = "main_user_pool"
}

# Cognito user pool client
resource "aws_cognito_user_pool_client" "main_client" {
  name               = "main_user_pool_client"
  user_pool_id       = aws_cognito_user_pool.main.id
  generate_secret    = false
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows = ["code"]
  allowed_oauth_scopes = ["openid", "email", "profile"]
}

# Cognito user pool domain
resource "aws_cognito_user_pool_domain" "main_domain" {
  domain       = "main-user-pool-domain"
  user_pool_id = aws_cognito_user_pool.main.id
}

# Cognito user group
resource "aws_cognito_user_group" "main_group" {
  name         = "main_user_group"
  user_pool_id = aws_cognito_user_pool.main.id
}

# Cognito user
resource "aws_cognito_user" "main_user" {
  username         = "main_user"
  user_pool_id     = aws_cognito_user_pool.main.id
  desired_delivery_mediums = ["EMAIL"]
  force_alias_creation = true
  message_action = "SUPPRESS"
  user_attributes {
    name  = "email"
    value = "user@example.com"
  }
}

# Cognito user group membership
resource "aws_cognito_user_group_membership" "main_membership" {
  username      = aws_cognito_user.main_user.username
  group_name    = aws_cognito_user_group.main_group.name
  user_pool_id  = aws_cognito_user_pool.main.id
}

#Create API Gateway
resource "aws_api_gateway_rest_api" "main" {
  name        = "FileSearchAPI"
  description = "API for searching files"
}

resource "aws_api_gateway_deployment" "main" {
  depends_on  = [aws_api_gateway_integration.files_get]
  rest_api_id = aws_api_gateway_rest_api.main.id
  stage_name  = "prod"
}

resource "aws_api_gateway_api_key" "access" {
  name        = "access-key"
  description = "Key for access"
  enabled     = true
}

resource "aws_api_gateway_usage_plan" "main" {
  name        = "UsagePlan"
  description = "Monthly usage plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.main.id
    stage  = aws_api_gateway_deployment.main.stage_name
  }

  quota_settings {
    limit  = 5000
    offset = 2
    period = "MONTH"
  }

  throttle_settings {
    burst_limit = 20
    rate_limit  = 10
  }
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.access.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.main.id
}


# Create EKS Cluster for microservices deployment

resource "aws_eks_cluster" "example" {
  name     = "example"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = [aws_subnet.example.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.eks_cluster_AmazonEKSVPCResourceController,
  ]
}

resource "aws_iam_role" "eks_cluster" {
  name = "example_eks_cluster_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_eks_node_group" "example" {
  cluster_name    = aws_eks_cluster.example.name
  node_group_name = "example-node-group"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = [aws_subnet.example.id]

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
}

resource "aws_iam_role" "eks_node" {
  name = "example_eks_node_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node.name
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node.name
}

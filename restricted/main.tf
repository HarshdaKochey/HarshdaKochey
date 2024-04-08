resource "aws_iam_policy" "s3_access_policy" {
  name        = "s3_access_policy"
  description = "Allows Lambda to access S3 buckets and read object metadata"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:GetObjectAcl"
      ],
      Effect = "Allow",
      Resource = [
        "${aws_s3_bucket.file_upload_bucket.arn}/*",
        "${aws_s3_bucket.processed_files_bucket.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_attachment" {
  policy_arn = aws_iam_policy.s3_access_policy.arn
  role       = aws_iam_role.lambda_role.name
}

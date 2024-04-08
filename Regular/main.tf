resource "aws_s3_bucket" "file_upload_bucket" {
    bucket = "my-file-upload-bucket"
    acl    = "private"
}

resource "aws_s3_bucket" "processed_files_bucket" {
    bucket = "my-processed-files-bucket"
    acl    = "private"
}


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

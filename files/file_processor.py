import boto3 # Imports the boto3 library, which is the AWS SDK for Python, allowing you to interact with AWS services.
import os # Imports the os module, which provides functions for interacting with the operating system.
from botocore.exceptions import NoCredentialsError # Imports the ClientError exception from botocore.exceptions, which is part of the Boto3 library.

s3_client = boto3.client('s3') #This line creates an S3 client using the boto3 library, which is the Amazon Web Services (AWS) SDK for Python. This client will be used to interact with the S3 service.

def lambda_handler(event, context): #This line defines the entry point for the Lambda function. AWS Lambda invokes this function using the event and context parameters.
    source_bucket = event['Records'][0]['s3']['bucket']['name'] # Retrieves the name of the S3 bucket from the event object.
    file_key = event['Records'][0]['s3']['object']['key'] # Retrieves the key (file name) of the S3 object from the event object.

    try: # Begins a try block to catch exceptions that may occur during execution.        
        file_obj = s3_client.get_object(Bucket=source_bucket, Key=file_key) #This line tries to get the file object from the S3 bucket using the bucket name and file key.

        #Below lines extract the metadata from the file object. The metadata includes the content type, file size, and upload date.      
        metadata = file_obj['Metadata']
        content_type = metadata.get('content-type', '')
        file_size = int(metadata.get('file-size', '0'))
        upload_date = metadata.get('upload-date', '')

      #This block checks if any of the required metadata is missing. If so, it raises a ValueError.
        if not content_type or not file_size or not upload_date:
            raise ValueError("Missing required metadata.")

        # This line gets the name of the destination bucket from an environment variable.
        destination_bucket = os.environ['PROCESSED_FILES_BUCKET']

        # These lines copy the file from the source bucket to the destination bucket.
        copy_source = {
            'Bucket': source_bucket,
            'Key': file_key
        }
        s3_client.copy(copy_source, destination_bucket, file_key)

        # Delete the file from the source bucket
        s3_client.delete_object(Bucket=source_bucket, Key=file_key)

    except NoCredentialsError:
        print("Credentials not available")
        return None
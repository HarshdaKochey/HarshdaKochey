import boto3

s3 = boto3.client('s3')

def lambda_handler(event, context):
    # Get bucket name and key from the S3 event
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']

    # Get metadata
    response = s3.head_object(Bucket=bucket, Key=key)
    metadata = response['Metadata']

    # Check conditions and decide whether to move the file
    if check_conditions(metadata):
        # Copy the object to the second bucket
        s3.copy_object(Bucket='my-processed-files-bucket', CopySource={'Bucket': bucket, 'Key': key}, Key=key)

        # Delete the original object
        s3.delete_object(Bucket=bucket, Key=key)

def check_conditions(metadata):
    # Implement your conditions here
    pass

import json
import boto3


def lambda_handler(event, context):
    # TODO implement
    print(json.dumps(event))

    s3 = boto3.client('s3')
    dynamodb = boto3.resource('dynamodb')

    # record = event['Records']

    s3bucket = event["detail"]["requestParameters"]["bucketName"]
    s3object = event["detail"]["requestParameters"]["key"]

    print(s3bucket, s3object)

    # check file extension

    extension = s3object.split(".")[1]
    print(extension)

    if extension == "jpg":
        metadata = s3.head_object(Bucket=s3bucket, Key=s3object)

        print(metadata)
        # converting values in dictionary to string in order to store them in the dynambo table

        keys = metadata.items()
        metadata_new = {str(key): str(value) for key, value in keys}

        # adding value for key "Image" created in the "Images" table
        metadata_new["Image"] = "myimage"

    table = dynamodb.Table('Images')

    # updating table Images with values in the dictionay metadata_new

    table.put_item(Item=metadata_new)

    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }
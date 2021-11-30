import json
import boto3


def lambda_handler(event, context):
    # TODO implement
    print(json.dumps(event))
    s3 = boto3.resource('s3')

    # record = event['Records']

    s3bucket = event['S3Bucket']
    s3object = event['S3Prefix']
    Petname = event['PetName']

    obj = s3.Object(s3bucket, s3object)
    result = obj.get()['Body'].read().decode('utf-8-sig')
    text = json.loads(result)

    for attr in text['pets']:
        if attr['name'] == Petname:
            print(attr['favFoods'])
            break

    return {
        'statusCode': 200,
        'body': json.dumps('Hello from Lambda!')
    }

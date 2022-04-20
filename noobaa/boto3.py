#!/bin/env python

import boto3

AWS_ACCESS_KEY_ID = ""
AWS_SECRET_ACCESS_KEY = ""

def permanently_delete_object(bucket, object_key):
    """
    Permanently deletes a versioned object by deleting all of its versions.

    Usage is shown in the usage_demo_single_object function at the end of this module.

    :param bucket: The bucket that contains the object.
    :param object_key: The object to delete.
    """
    try:
        bucket.object_versions.filter(Prefix=object_key).delete()
        logger.info("Permanently deleted all versions of object %s.", object_key)
    except ClientError:
        logger.exception("Couldn't delete all versions of %s.", object_key)
        raise

def list_buckets():
    """
    List all available bucket
    """
    for bucket in s3.buckets.all():
        print(bucket.name)

def list_all_objects(bucket):
    """
    List all objects in a bucket
    """
    for obj in bucket.objects.all():
        print('{0}:{1}'.format(bucket.name, obj.key))

s3 = boto3.resource(
    's3',
    endpoint_url = 'https://s3-openshift-storage.apps.ocp.aws.tntinfra.net',
    verify = False,
    aws_access_key_id = AWS_ACCESS_KEY_ID,
    aws_secret_access_key = AWS_SECRET_ACCESS_KEY,
)

bucket = s3.Bucket('first.bucket')
list_all_objects(bucket)

# try:
#     mirrored.object_versions.filter(Prefix="README.md").delete()
# except ClientError:
#     print("Couldn't delete all versions of %s.", object_key)
#     raise

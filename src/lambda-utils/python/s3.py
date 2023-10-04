"""
boto3 s3 utils for lambdas
"""

import logging
import os

import boto3
import botocore

logging.getLogger("boto3").setLevel(logging.INFO)
logging.getLogger("botocore").setLevel(logging.INFO)

logger = logging.getLogger(__name__)
s3_res = boto3.resource("s3")
s3_client = boto3.client("s3")


def s3_download(bucket, key, local_path=None, force=False):
    """
    Download file from s3 bucket/key returns local path
    """

    if not local_path:
        local_path = f"/tmp/{bucket}/{key}"

    logger.info("s3_download: s3://%s/%s => local_path: %s", bucket, key, local_path)

    if os.path.exists(local_path) and not force:
        logger.info("s3_download: local_path exists: %s", local_path)
        return local_path

    try:
        os.makedirs(os.path.dirname(local_path), exist_ok=True)
        s3_bucket = s3_res.Bucket(bucket)
        s3_bucket.download_file(key, local_path)

    except botocore.exceptions.ClientError as e:
        if e.response["Error"]["Code"] == "404":
            logger.error("object does not exist at s3://%s/%s", bucket, key)
            local_path = None
        else:
            logger.error(str(e))
            raise e

    logger.info("s3_download: local_path: %s", local_path)
    return local_path


def s3_download_url(url, local_path=None, force=False):
    """
    s3_download_url
    """
    bucket, key = url_to_s3(url)
    return s3_download(bucket, key, local_path, force)


def s3_upload(local_path, bucket, key=None, force=False):
    """
    s3_upload
    """
    if not key:
        key = os.path.basename(local_path)

    # is
    exists = False  # True

    # try:
    #    if not force: # skip exist check if force
    #        s3.head_object(Bucket=bucket, Key=key)
    #
    # except botocore.exceptions.ClientError as e:
    #    if e.response['Error']['Code'] == "404":
    #        exists = False
    # else:
    #  # Something else has gone wrong.
    #  raise e

    if not exists or force:
        with open(local_path, "rb") as data:
            s3_client.upload_fileobj(Fileobj=data, Bucket=bucket, Key=key)

    return bucket, key


def s3_upload_url(local_path, url, force=False):
    """
    s3_upload_url
    """
    bucket, key = url_to_s3(url)
    return s3_upload(local_path, bucket, key, force)


def s3_to_url(bucket, key):
    """
    s3_to_url
    """
    if bucket.contains("/"):
        raise ValueError(f"bucket should not include the / character ({bucket})")

    return f"s3://{bucket}/{key}"


def url_to_s3(url):
    """
    url_to_s3
    """
    bucket = None
    key = None

    #
    # format is s3://bucket/key
    # so splitting with maxsplits=4 yields:
    #
    # url_parts = ("s3:","",bucket,key)
    #
    # Notice : key may include "/" but bucket should not.
    #

    url_parts = url.split("/", 3)
    logger.info("url_to_s3 : %s => %s", url, url_parts)
    try:
        if url_parts[0] != "s3:":
            raise ValueError(f"not a valid s3 url : {url}")

        bucket = url_parts[2]
        key = url_parts[3]

    except KeyError as e:
        logger.error(str(e))
        raise

    return bucket, key

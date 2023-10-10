"""
aws lambda handler entry point
"""
import json
import logging
import os
import replicate

if logging.getLogger().hasHandlers():
    # The Lambda environment pre-configures a handler logging to stderr.
    # If a handler is already configured,`.basicConfig` does not execute.
    # Thus we set the level directly.
    logging.getLogger().setLevel(logging.INFO)
else:
    logging.basicConfig(level=logging.INFO)

logger = logging.getLogger(__name__)

#
# lambda-utils should be in path or included as a lambda layet or 
# as a docker public.ecr.aws/lambda based image in /opt (see Dockerfile).
#
from events import s3_event, s3_test_event
from misc_utils import json_str, zip_path
from s3 import s3_download, s3_upload
from secrets_manager import SecretManager

def lambda_handler(event, unused_context):
    """
    aws lambda handler entry point
    """

    region = os.environ["AWS_REGION"]
    logger.info("Region %s Event: %s", region, json_str(event))

    results = []
    event_records = event["Records"] if event and "Records" in event else []
    logger.info("event_records : %s", event_records)

    for event_record in event_records:
        job = process_one_event_record(event_record)
        logger.info("record job: %s", job)

        if job:
            res = process_one_job(job)
        else:
            res = {"error": f"unknown job from event_record {event_record}"}

        results.append(res)

    logger.info("lambda_handler results: %s", json_str(results))
    return results


def process_one_event_record(event_record):
    """
    process_one_event_record: we are looking for s3 events or test events
    """
    job = s3_event(event_record) or s3_test_event(event_record)
    return job


def process_one_job(job):
    """
    process_one_job
    """
    logger.info("process_one_job job: %s", json_str(job))
    res = None

    # download s3 job manifest
    bucket = job["s3BucketName"] if "s3BucketName" in job else None
    key = job["s3ObjectKey"] if "s3ObjectKey" in job else None

    if not bucket or not key:
        return {"error": f"missing bucket({bucket}) or key{key}"}

    manifest_path = s3_download(bucket, key)
    logger.info("manifest_path : %s", manifest_path)

    # parse local manifest:
    if not manifest_path:
        return {"error": f"failed to download manifest s3://{bucket}/{key}"}

    manifest = None
    try:
        with open(manifest_path, "r", encoding="UTF-8") as json_fp:
            manifest = json.load(json_fp)

    except (ValueError, AttributeError, KeyError) as e:
        logger.error(str(e))

    logger.info("manifest", manifest)

    if manifest:
        output = process_job_manifest(manifest)
        res = {"manifest": manifest, "output": output}
    else:
        res = {}

    logger.info("process_one_job res: %s", res)
    return res

def process_one_job_get_manifest(job):
    """
    Not implemented yet - move to lambda_units?!    
    """
    ...

def process_job_manifest(manifest):

    token = SecretManager.setup_os_env("replicate-api-token", env_variable="REPLICATE_API_TOKEN")
    if not token:
        logger.error("REPLICATE_API_TOKEN is required")
        return {}
    
    logger.info("REPLICATE_API_TOKEN set - %s", token)
    
    output = replicate.run(
        "xinntao/realesrgan:1b976a4d456ed9e4d1a846597b7614e79eadad3032e9124fa63859db0fd59b56",
        input={"img": open("./test.jpg", "rb")}
    )

    print(manifest)
    print(output)

    return output
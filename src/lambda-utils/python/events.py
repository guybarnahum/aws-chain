"""
event
"""
import logging
from functools import reduce

from misc_utils import json_str

logger = logging.getLogger(__name__)


def s3_event(event_record):
    """
    s3_event converts an s3_event into job
    {
        "eventSource": "aws:s3",
        "eventName": "ObjectCreated:Put",
        ...
        "s3": {
        ...
            "bucket": {
                "name": "add-prompt-lambda-bucket-us-west-2",
                ...
            },
            "object": {
                "key": "input/6961627861_3596b99c3f_o.jpg",
                ...
            }
        }
    }
    """
    event_keys = {"s3ObjectKey": "s3.object.key", "s3BucketName": "s3.bucket.name"}
    return event_process(event_record, type_key="s3", event_keys=event_keys)


def s3_test_event(event_record):
    """
    lambda_test_event : converts test event into job
    {
        "s3-test": true,
        "eventSource": "aws:s3",
        "eventName": "ObjectCreated:Put",
        "s3ObjectKey": "input/data/state_of_the_union/state_of_the_union.json",
        "s3BucketName": "add-prompt-lambda-bucket-us-west-2"
    }
    """
    event_record_keys = event_record.keys()
    event_keys = dict(zip(event_record_keys, event_record_keys))  # fetch all keys

    return event_process(event_record, type_key="s3-test", event_keys=event_keys)


def dyanamodb_stream_event(event_record):
    """
    dyanamodb_stream_event
    """

    event_keys = {
        "prompt_id": "dynamodb.OldImage.prompt_id.S",
    }
    job = event_process(event_record, type_key="dynamodb", event_keys=event_keys)

    # ttl is not suppolied by dyanamodb_stream_event - mark it as missing
    if job:
        job["ttl"] = None
    return job


def dyanamodb_stream_test_event(event_record):
    """
    dyanamodb_stream_test_event
    """
    event_record_keys = event_record.keys()
    # {"prompt_id": "prompt_id", "query": "query", "ttl": "ttl"}
    event_keys = dict(zip(event_record_keys, event_record_keys))  # fetch all keys
    return event_process(event_record, type_key="dynamodb-test", event_keys=event_keys)


def deep_get(dictionary, keys, default=None, delimiter=None):
    """
    get values for nested dict keys
    """
    delimiter = delimiter or "."
    return reduce(
        lambda d, key: d.get(key, default) if isinstance(d, dict) else default,
        keys.split(delimiter),
        dictionary,
    )


def event_sanity_check(event_record, type_key=None, type_name=None):
    """
    Test event by type key, in addition to existance of eventSource and
        eventName aws mandatory keys
    """
    logger.info("event_sanity_check >> type_key :%s type_name %s", type_key, type_name)
    if type_key not in event_record:
        logger.error("event malformed - missing required key: %s", type_key)
        return False

    if "skip-event" in event_record and event_record["skip-event"]:
        logger.info("event skip flag set - event skipped...")
        return False

    event_info = {}
    event_info["eventType"] = type_name or type_key

    try:
        event_info["eventSource"] = event_record["eventSource"]
        event_info["eventName"] = event_record["eventName"]
    except KeyError:
        logger.error("Invalid event missing eventSource or eventName")
        return False

    return event_info


def event_process(event_record, type_key, type_name=None, event_keys=None):
    """
    event_process sanity check rejection of event, followed by
        deep key value extraction for processing
    """
    type_name = type_name or type_key

    job = event_sanity_check(event_record, type_key, type_name)
    if not job or job["eventType"] != type_name:
        return False

    for name, key_ in event_keys.items():
        value_ = deep_get(event_record, key_)
        if value_:
            job[name] = value_
        else:
            logger.error("missing %s in %s event", key_, job["eventName"])

    logger.info("event_process >> job :%s", json_str(job))
    return job

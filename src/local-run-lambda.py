"""
Run lambda code locally for development..
Notice: AWS Lambda execution environment is different than local one.
Consider running dockerized AWS Lambda image for a more realistic approximation

Still, some may find this useful for debugging "lite" buisness logic.
"""
import importlib
import json
import logging
import os
import sys
import time
from argparse import ArgumentParser

if logging.getLogger().hasHandlers():
    # The AWS Lambda environment pre-configures a handler logging to stderr.
    # If a handler is already configured,`.basicConfig` does not execute.
    # Thus we set the level directly.
    logging.getLogger().setLevel(logging.INFO)
else:
    logging.basicConfig(level=logging.INFO)

logger = logging.getLogger(__name__)

def validate_aws_env():
    """
    Validate AWS lambda "compatible" environment
    Returns: Error String or None for no errors
    """
    err = None
    
    try:
        import boto3
    except ModuleNotFoundError as e:
        logger.error(str(e))

    if "boto3" not in sys.modules:
        err = "aws boto3 module not installed"
    elif not os.path.isfile(os.path.expanduser("~/.aws/credentials")):
        err = "aws credentials missing"
    elif not os.path.isfile(os.path.expanduser("~/.aws/credentials")):
        err = "aws credentials missing"
    elif not os.path.isfile(os.path.expanduser("~/.aws/config")):
        err = "aws config missing"

    return err

def sys_path_add(paths):
    """
    sys_path_add
    """
    paths = "".join(paths.split())
    for path in paths.split(","):
        full_path = os.path.abspath(path)
        sys.path.append(full_path)
        logger.debug("sys.path <= %s", full_path)


sys_path_add(
    """
    lambda-utils/python,
    src/lambda-utils/python,
    """
)

from misc_utils import set_into_object

def load_event_file(event_file, option=None):
    """
    load_event_file from json test file
    """

    logger.debug("load_event_file %s.%s", event_file, option)
    obj = None
    try:
        with open(event_file, "r", encoding="utf-8") as json_file:
            obj = json.load(json_file)
    except IOError as e:
        logger.error(str(e))
    except json.JSONDecodeError as e:
        logger.error(str(e.msg))

    if not obj:
        logger.error("Could not load json file %s", event_file)
        return None

    event = obj
    try:
        if "openapi" in obj:
            events = obj["components"]["examples"]
            logger.info("event found: %s", events.keys())
            if not option:
                option = list(events.keys())[0]

            event = events[option] if option in events else None

            if not event:
                logger.error("No %s in test event list", option)

            event = event["value"] if "value" in event else None

    except KeyError:
        logger.info("not an valid openapi event - simple event found")
        event = obj

    logger.debug("event file %s, option %s, event %s", event_file, option, event)
    return event

def main():
    """
    aws lambda handler entry point
    """

    aws_env_err = validate_aws_env()
    if aws_env_err :
        logger.error( aws_env_err )
        exit();

    parser = ArgumentParser(
        prog="local-run-lambda",
        description="Run aws lambda locally, useful for development",
        epilog="""
        Invocation events are kept in data/events,
        default for lambda is data/events/<lambda>.json
        """,
    )

    parser.add_argument("lambda_path")
    parser.add_argument("-e", "--event")
    parser.add_argument("-s", "--select")
    parser.add_argument("-v", "--verbose", action="store_true")  # on/off flag

    args, unknown = parser.parse_known_args()
    logger.debug("args %s", args)

    event_overrides = dict(arg.split("=") for arg in unknown if "=" in arg)
    logger.info("event overrides: %s", event_overrides)

    event_path = args.event
    event_option = args.select
    lambda_path = args.lambda_path
    lambda_module = f"{lambda_path}.lambda"

    if not event_path:
        event_path = f"data/events/{lambda_path}.json"

    logger.info("event_path %s", event_path)

    event = load_event_file(event_path, event_option)
    event = set_into_object(
        event, event_overrides
    )  # event overrides from supplied args
    context = {}

    start_time = time.time()

    module = importlib.import_module(lambda_module)
    res = module.lambda_handler(event, context)
    logger.info("res : %s", res)

    logger.info("--- %s sec ---", round(time.time() - start_time, 3))

if __name__ == "__main__":
    main()
"""
manage secrets
"""
import json
import logging
import os

import boto3
from botocore.exceptions import ClientError
from misc_utils import json_str

logging.getLogger("boto3").setLevel(logging.WARNING)
logging.getLogger("botocore").setLevel(logging.WARNING)

logger = logging.getLogger(__name__)


class SecretManager:
    """
    SecretManager
    """

    _instance = None
    _region = os.environ["AWS_REGION"]
    _session = boto3.session.Session()
    _secret_manager = None
    _secrets_cache = {}
    _cache_path = "/tmp/SecretManager_secrets_cache.json"

    def __init__(self):
        """
        singlton __init__ is forbidden
        """
        raise RuntimeError("Singleton, use methods directly")

    @classmethod
    def get_secret(cls, secret_id, secret_key=None):
        """
        get_secret
        """
        logger.debug("SecretManager.get_secret(%s,%s)", secret_id, secret_key)

        # instanciate if needed
        if cls._instance is None:
            logger.debug("cls. new instance")
            cls._instance = cls.__new__(cls)
            cls._secret_manager = cls._session.client(
                service_name="secretsmanager", region_name=cls._region
            )
            cls.load_cache()
        else:
            logger.debug("cls._instance found!")

        if not secret_key:
            secret_key = secret_id  # short hand for key
        cache_key = secret_id + "." + secret_key

        logger.debug("SecretManager.get_secret cache_key %s", cache_key)

        secret_value = (
            cls._secrets_cache[cache_key] if cache_key in cls._secrets_cache else None
        )
        if not secret_value:
            secret_value = cls.get_secret_from_secrect_manager(secret_id, secret_key)

        if secret_value:
            cls._secrets_cache[cache_key] = secret_value
            cls.store_cache()

        logger.debug(
            "SecretManager.get_secret secret_value %s cache %s",
            secret_value,
            json_str(cls._secrets_cache),
        )
        return secret_value

    @classmethod
    def get_secret_from_secrect_manager(cls, secret_id, secret_key=None):
        """
        get_secret_from_secrect_manager
        """
        logger.debug(
            "SecretManager.get_secret_from_secrect_manager(%s,%s)",
            secret_id,
            secret_key,
        )

        if not secret_key:
            secret_key = secret_id  # short hand for key

        try:
            res = cls._secret_manager.get_secret_value(SecretId=secret_id)
        except ClientError as e:
            res = {}
            error = str(e)
            if e.response["Error"]["Code"] == "ResourceNotFoundException":
                error += f"The requested secret '{secret_id}' was not found"
            elif e.response["Error"]["Code"] == "InvalidRequestException":
                error += "The request was invalid"
            elif e.response["Error"]["Code"] == "InvalidParameterException":
                error += "The request had invalid params"
            elif e.response["Error"]["Code"] == "DecryptionFailure":
                error += (
                    "The requested secret can't be decrypted using the provided KMS key"
                )
            elif e.response["Error"]["Code"] == "InternalServiceError":
                error += "An error occurred on service side"
            logger.error(error)

        # Secrets Manager decrypts the secret value using the associated KMS CMK
        # Depending on whether the secret was a string or binary,either SecretString
        # or SecretBinary will be set
        #
        # This code supports only string secret at this time
        secret_json = res["SecretString"] if "SecretString" in res else "{}"

        # now get the value from the json string

        logger.debug(
            "SecretManager.get_secret_from_secrect_manager json: '%s'", secret_json
        )
        secret_entry = json.loads(secret_json)

        secret_value = secret_entry[secret_key] if secret_key in secret_entry else None
        logger.debug(
            "SecretManager.get_secret_from_secrect_manager secret_value: '%s'",
            secret_value,
        )
        return secret_value

    @classmethod
    def load_cache(cls):
        """
        load_cache
        """
        logger.debug("load_cache @ %s", cls._cache_path)
        try:
            with open(cls._cache_path, "r", encoding="utf8") as cache_file:
                js_str = cache_file.read()
                logger.debug("load_cache: js_str %s", js_str)
                cls._secrets_cache = json.loads(js_str)

        except FileNotFoundError:
            logger.info("load_cache: cache not found in lambda's ephemeral storage")
        except json.JSONDecodeError as e:
            logger.error("load_cache JSONDecodeError: %s", str(e))
        else:
            logger.info("load_cache: cache %s", json_str(cls._secrets_cache))

    @classmethod
    def store_cache(cls):
        """
        save_cache
        """
        logger.debug(
            "store_cache: %s << %s", cls._cache_path, json_str(cls._secrets_cache)
        )

        with open(cls._cache_path, "w", encoding="utf8") as cache_file:
            json.dump(cls._secrets_cache, cache_file)
            cache_file.truncate()
            cache_file.flush()

        # with open(cls._cache_path, "r", encoding="utf8") as cache_file:
        #    js_str = cache_file.read()
        #    logger.debug("store_cache: read written js_str %s", js_str)

    @classmethod
    def setup_os_env(cls, secret, env_variable=None):
        """
        setup_os_env
        """
        if not env_variable:
            env_variable = secret.upper().replace("-", "_")

        secret_value = SecretManager.get_secret(secret)
        if not secret_value:
            logger.error("Could not get %s secret...", secret)
        else:
            logger.info("ENV %s <= %s(%s)", env_variable, secret, secret_value)
            os.environ[env_variable] = secret_value
        return secret_value

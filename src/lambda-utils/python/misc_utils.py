"""
boto3 dynamodb utils for lambdas
"""
import base64
import decimal
import hashlib
import json
import logging
import os
import zipfile

logger = logging.getLogger(__name__)


class JsonEncoder(json.JSONEncoder):
    """
    adds json Decimal support- usage :json.dumps(obj, cls=JsonEncoder)
    """

    def default(self, o):
        if isinstance(o, decimal.Decimal):
            return float(o)
        return json.JSONEncoder.default(self, o)


def hash_id(data):
    """
    generate a somewhat short alphanumeric id from text
    """
    id_from_data = base64.urlsafe_b64encode(hashlib.md5(data.encode("utf-8")).digest())
    id_from_data = id_from_data.decode("ascii")
    logger.debug("generated id : %s", id_from_data)
    return id_from_data


def json_encode_obj(obj):
    """
    JsonEncodeObj for complex data types
    {cls.__module_}.
    """
    cls = obj.__class__
    return f"<{cls.__qualname__} obj at {id(obj)}>"


def json_str(obj):
    """
    json_str
    """
    return json.dumps(
        obj, indent=4, sort_keys=True, default=json_encode_obj, cls=JsonEncoder
    )


def get_from_object(obj, path):
    """
    get_from_object
    """
    keys = path.split(".")
    for key in keys:
        if not obj:
            break
        obj = obj[key] if key in obj else None

    logger.info("get_from_object %s => %s", path, json_str(obj))
    return obj


def set_into_object(obj, overrides):
    """
    set_into_object
    """
    for path, value in overrides.items():
        curr = obj
        keys = path.split(".")
        latest = keys.pop()
        for key in keys:
            if key.isnumeric():
                key = int(key)
            else:
                curr[key] = curr[key] if key in curr else {}
            curr = curr[key]
        curr[latest] = value
        logger.info("set_into_object %s <= %s", path, value)

    return obj


def unzip_zip(zip_file, local_path=None, force=False):
    """
    unzip zip files into local directory
    """

    if not local_path:
        local_path = os.path.dirname(zip_file)
    if os.path.exists(local_path) and not force:
        return local_path

    with zipfile.ZipFile(zip_file) as archive:
        for file in archive.namelist():
            archive.extract(file, local_path)

    return local_path


def zip_path(local_path, zip_file, force=False):
    """
    zip local directory files into zip file
    """
    if not zip_file:
        raise ValueError("zip_file value missing")
    if not local_path:
        raise ValueError("local_path value missing")

    if os.path.exists(zip_file) and not force:
        return zip_file

    working_dir = os.getcwd()
    os.chdir(os.path.dirname(local_path))

    with zipfile.ZipFile(
        zip_file, "w", zipfile.ZIP_DEFLATED, allowZip64=True
    ) as zipfile_object:
        for root, _, filenames in os.walk(os.path.basename(local_path)):
            for name in filenames:
                name = os.path.join(root, name)
                name = os.path.normpath(name)
                zipfile_object.write(name, name)

    os.chdir(working_dir)
    return zip_file

"""
boto3 dynamodb utils for lambdas
"""
import logging
import random

import boto3
from boto3.dynamodb.types import TypeDeserializer
from misc_utils import json_str

logging.getLogger("boto3").setLevel(logging.WARNING)
logging.getLogger("botocore").setLevel(logging.WARNING)

logger = logging.getLogger(__name__)

db = boto3.client("dynamodb")
db_deserializer = TypeDeserializer()


def get_item(table, item_id, cols=None):
    """
    get_item
    """

    logger.info("get_item: %s %s %s", table, item_id, cols)

    if not item_id:
        return None
    if cols:
        res = db.get_item(
            TableName=table, Key={"id": {"S": item_id}}, ProjectionExpression=cols
        )
    else:
        res = db.get_item(TableName=table, Key={"id": {"S": item_id}})
    logger.info("get_item: %s", json_str(res))

    # unpack response
    try:
        db_item = res["Item"]
        if not db_item:
            return None
        item = {k: db_deserializer.deserialize(v) for k, v in db_item.items()}
    except KeyError:
        logger.error("could not find item (id:%s) in %s", item_id, table)
        item = None

    logger.info("get_item returned: %s", json_str(item))
    return item


def dump_db_items(db_items):
    """
    dump_db_items
    """
    for i in db_items:
        logger.info("list item: %s", json_str(i))
        for k, value in i.items():
            logger.info(
                "item key:%s value:%s ",
                json_str(k),
                json_str(value),
            )


def get_items(table, ids, key="id", cols=None):
    """
    get_items
    """

    if not ids:
        return None
    one_only = len(ids) == 1
    if one_only:
        items = [get_item(table, ids[0], cols)]
        logger.debug("get_items returned: %s", json_str(items))
        return items

    keys = [{key: {"S": v}} for v in ids]
    logger.debug("get_items keys: %s", json_str(keys))

    if cols:
        res = db.batch_get_item(
            RequestItems={
                table: {
                    "Keys": keys,
                    "ConsistentRead": True,
                    "ProjectionExpression": cols,
                }
            }
        )
    else:
        res = db.batch_get_item(
            RequestItems={
                table: {
                    "Keys": keys,
                    "ConsistentRead": True,
                }
            }
        )
    logger.debug("batch_get_item: %s", json_str(res))

    # unpack response

    try:
        db_items = res["Responses"][table]
        if not db_items:
            return None

        # dump_db_items(db_items)

        items = [
            {u: db_deserializer.deserialize(w) for u, w in v.items()} for v in db_items
        ]

    except KeyError:
        logger.error("could not find prompts for keys: %s", json_str(keys))
        items = None

    logger.debug("get_items returned: %s", json_str(items))
    return items


def query(
    table,
    index,
    expr,
    do_random=False,
    do_limit=None,
):
    """
    query
    """

    # unpack the many arguments for dynamodb query
    expr_cond = expr["condition"]
    expr_filter = expr["filter"] if "filter" in expr else None
    expr_values = expr["values"]
    expr_cols = expr["cols"] if "cols" in expr else ""

    if expr_filter:
        res = db.query(
            TableName=table,
            IndexName=index,
            KeyConditionExpression=expr_cond,
            FilterExpression=expr_filter,
            ExpressionAttributeValues=expr_values,
            ProjectionExpression=expr_cols,
        )
    else:  # <-- no filter: FilterExpression can't be None
        res = db.query(
            TableName=table,
            IndexName=index,
            KeyConditionExpression=expr_cond,
            ExpressionAttributeValues=expr_values,
            ProjectionExpression=expr_cols,
        )

    # Traslate db low level representation to `normal` python list
    db_items = res["Items"] if "Items" in res else None
    logger.debug("query db_items : %s", json_str(db_items))
    if not db_items:
        return None

    # dump_db_items(db_items)

    items = [
        {k: db_deserializer.deserialize(v) for k, v in i.items()} for i in db_items
    ]
    logger.debug("items : %s", json_str(items))

    one_only = len(items) == 1  # check again if we have only one

    # shuffle only if we have more than one
    if do_random and not one_only:
        random.shuffle(items)
    if do_limit:
        items = items[:do_limit]

    logger.debug("query returned: %s", json_str(items))
    return items


def value_to_db_value(value):
    """
    value_to_db_value constructs dynammodb value object
    """
    value_type = value_to_db_type(value)
    db_value = None

    if value_type == "S":
        db_value = {"S": value}
    elif value_type == "N":
        db_value = {"N": str(value)}

    logger.debug("value %s into db_value %s", str(value), json_str(db_value))
    return db_value


def value_to_db_type(var):
    """
    value_to_db_type detects type of variable as dynammodb type
    """
    if isinstance(var, str):
        return "S"
    if isinstance(var, int):
        return "N"

    return None


def put_item(table, item):
    """
    put_item
    """
    # for k, val in item.items():
    #    logger.info("put_item item key: %s -> value:%s", k, str(val))

    db_item = {k: value_to_db_value(v) for k, v in item.items()}
    res = db.put_item(TableName=table, Item=db_item)
    logger.info("put_item res: %s", json_str(res))
    return res


def update_item(table, key, item):
    """
    update_item
    """
    db_key = {k: value_to_db_value(value) for k, value in key.items()}
    expr_update_list = ["SET"]
    expr_values = {}

    for k, value in item.items():
        expr_var = ":" + k
        expr_update_list.append(k + "=" + expr_var)

        logger.debug(
            'update_item expr_values:"%s":%s', expr_var, value_to_db_value(value)
        )

        expr_values[expr_var] = value_to_db_value(value)

    expr_update = " ".join(expr_update_list)

    logger.debug("update_item table=%s key=%s", table, json_str(key))
    logger.debug("update_item expr_update=%s", json_str(expr_update))
    logger.debug("update_item expr_values=%s", json_str(expr_values))

    res = db.update_item(
        TableName=table,
        Key=db_key,
        UpdateExpression=expr_update,
        ExpressionAttributeValues=expr_values,
        ReturnValues="UPDATED_NEW",
    )

    try:
        status = res["ResponseMetadata"]["HTTPStatusCode"]
    except KeyError:
        logger.error("unknown response : %s", json_str(res))
        status = 500  # internal error

    logger.info("put_item res: %s", json_str(res))
    return status

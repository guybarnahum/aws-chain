"""
prompt management (over dynamodb) utils for lambdas
"""
import logging
import time

import dynamodb
from misc_utils import hash_id, json_str

logger = logging.getLogger(__name__)


def get_prompt(prompt_id):
    """
    get_prompt
    """
    if not prompt_id:
        return None

    table = "prompts-table"
    item = dynamodb.get_item(table, prompt_id)
    logger.info("get prompt id=%s : %s", prompt_id, json_str(item))
    return item


def get_prompts(task_, type_, via_=None, do_random=True, do_limit=1):
    """
    get_prompts
    """

    if not task_:
        logger.error("get_prompts missing required task_")
        return None

    if not type_:
        logger.error("get_prompts missing required type_")
        return None

    # dynamodb query arguments
    table = "prompt-lookup-table"
    index = "task-type"

    query_expr = {
        "condition": "task_ = :task AND type_ = :type",
        "filter": "via_ = :via" if via_ else None,
        "values": {
            ":task": {"S": task_},
            ":type": {"S": type_},
            ":via": {"S": via_},
        }
        if via_
        else {":task": {"S": task_}, ":type": {"S": type_}},
        "cols": "prompt_ids",
    }

    items = dynamodb.query(table, index, query_expr, do_random, do_limit)

    try:
        ids = [i["prompt_ids"] for i in items]
    except KeyError:
        logger.error("get_prompts no ids found in response %s:", json_str(items))
        ids = None
    else:
        logger.debug("get_prompts ids: %s", json_str(ids))

    table = "prompts-table"
    prompts = (
        dynamodb.get_items(table, ids, cols="id,template,actors,res_id")
        if ids
        else None
    )
    logger.debug("get_prompts prompts: %s", json_str(prompts))

    return prompts


# def get_prompt_result():
#    """
#    Check if we have cached result already for given prompt
#    There results expire with ttl
#    """
#    ...


def put_prompt_result(prompt_id, result, result_id=None, ttl=None):
    """
    cache prompt result for later us
    """

    result_id = result_id if result_id else hash_id(result)
    created_at = int(time.time())
    ttl = ttl if ttl else (7 * 24 * 60 * 60)  # default ttl is one week
    ttl = created_at + ttl

    item = {
        "id": result_id,
        "prompt_id": prompt_id,
        "result": result,
        "created_at": created_at,
        "ttl": ttl,
    }

    logger.info("put_prompt_result item %s", json_str(item))
    res = dynamodb.put_item("prompt-results-table", item)
    logger.info("put_prompt_result res: %s", json_str(res))
    # to do: check for success
    return result_id


def get_prompt_results(res_ids):
    """
    Place holder for prompt results cache: return a cache miss..
    Do not invalidate any res_ids
    """
    prompt_result = None
    table = "prompt-results-table"

    while len(res_ids) > 0:
        res_id = res_ids.pop()
        item = dynamodb.get_item(table, res_id)  # , cols="result")
        if item:
            try:
                prompt_result = item["result"]
            except KeyError:
                logger.error(
                    "get_prompt_results invalid prompt result - %s",
                    json_str(item),
                )
        break

    if prompt_result:  # we had a good res_id! insert in list!
        res_ids.insert(0, res_id)

    return prompt_result, res_ids


def update_prompt_results(prompt_id, res_ids):
    """
    update_prompt_results
    """
    table = "prompts-table"
    key = {"id": prompt_id}
    item = {"res_id": " ".join(res_ids)}

    status = dynamodb.update_item(table, key, item)
    logger.info("update_prompot_result status %s ", str(status))
    return status

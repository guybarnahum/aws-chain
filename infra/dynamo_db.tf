# ............................................................ dynamo db tables

locals {
  db_tables = { for id, tbl in var.dynamodb_tables : id => tbl }
}

resource "aws_dynamodb_table" "dynamodb_table" {
  for_each       = local.db_tables
  name           = each.value.name
  billing_mode   = each.value.billing
  read_capacity  = each.value.read
  write_capacity = each.value.write
  hash_key       = each.value.hash_key
  tags           = each.value.tags

  dynamic "attribute" {
    for_each = each.value.attributes
    content {
      name = attribute.key
      type = attribute.value
    }
  }

  dynamic "global_secondary_index" {
    for_each = each.value.indexes
    content {
      name            = global_secondary_index.key
      hash_key        = global_secondary_index.value.hash_key
      range_key       = global_secondary_index.value.range_key
      projection_type = "ALL"
      read_capacity   = 0
      write_capacity  = 0
    }
  }

  # Need to treat ttl_tables and non_ttl_tables due to bug in terraform
  # aws_dynamodb_table - with ttl disabled, can't "terraform apply" twice
  # https://github.com/hashicorp/terraform-provider-aws/issues/10304

  dynamic "ttl" {
    for_each = [for yeild_one_ttl_block in ["once"] : yeild_one_ttl_block if each.value.ttl]
    content {
      enabled        = true  // enabling TTL
      attribute_name = "ttl" // the attribute name which enforces TTL,
      // must be a Number (Timestamp)
    }
  }

  stream_enabled   = each.value.stream
  stream_view_type = "NEW_AND_OLD_IMAGES"

  server_side_encryption {
    enabled = true // false -> use AWS Owned CMK,
    // true -> use AWS Managed CMK,
    // true + key arn -> use custom key
  }

  lifecycle {
    // If autoscaling is on, should add lifecycle ignore_changes
    // for read write because every time apply, it will set the
    // read and write back to min value.
    ignore_changes = [
      read_capacity,
      write_capacity
    ]
  }
}

# ........................................................... db tables seeders

locals {
  db_table_seeders = {
    for id, tbl in var.dynamodb_tables : id => tbl if tbl.seed != null
  }

  db_table_tf_data_seeds = {
    for id, tbl in local.db_table_seeders :
    id => {
      table_name = tbl.name
      hash_key   = tbl.hash_key
      tf_data    = jsondecode(file(tbl.seed))
      hash       = filesha256(tbl.seed)
    }
  }

  db_table_tf_data_items = flatten([
    for id, tbl in local.db_table_tf_data_seeds : [
      for tf_data_item in tbl.tf_data : {
        table_name = tbl.table_name,
        hash_key   = tbl.hash_key
        hash       = tbl.hash
        item       = jsonencode(tf_data_item)
      }
      # skip invalid items. Used for commenting json files
      if lookup(tf_data_item, tbl.hash_key, false) != false # force a bool value
    ]
  ])
}

resource "aws_dynamodb_table_item" "dynamodb_table_item" {
  count      = length(local.db_table_tf_data_items)
  table_name = local.db_table_tf_data_items[count.index].table_name
  hash_key   = local.db_table_tf_data_items[count.index].hash_key
  item       = local.db_table_tf_data_items[count.index].item

  // Make sure we have table resources before adding items
  // At the risk of a race condition
  depends_on = [
    aws_dynamodb_table.dynamodb_table
  ]

  lifecycle {
    ignore_changes = [
      item
    ]
  }
}

# ..................................................................... outputs

output "db_tables_output" {
  description = "db_tables list"
  value       = var.enable_outputs ? local.db_tables : null
}

output "db_table_tf_data_seeds" {
  description = "db_table_tf_data_seeds list"
  value       = var.enable_outputs ? local.db_table_tf_data_items : null
}

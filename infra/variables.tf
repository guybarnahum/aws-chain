variable "enabled_seeding" {
  type        = bool
  default     = false # <-- default to avoid seeding as it overwrites runtime values.
  description = "Unimplemented - enable / disable seeding of table items"
}

variable "enable_outputs" {
  type        = bool
  default     = false # <-- default to avoid outputs
  description = "enable / disable outputs"
}

variable "lambda_runtime" {
  type        = string
  default     = "python3.11"
  description = "lambda runtime environment"
}

variable "lambda_timeout" {
  type        = string
  default     = "900"
  description = "lambda maximum execution time before it is aborted"
}

variable "lambda_memory" {
  type        = string
  default     = "128"
  description = "lambda memory and execution cpu (affects cost)"
}

variable "lambda_architectures" {
  type        = list(any)
  default     = ["x86_64"] # ["arm64"] #
  description = "cpu architecture type x86_64 / arm64 (affects cost)"
}

# ............................................................... lambda_layers

variable "lambda_layers" {
  type = map(object({
    src_zip  = string
    src_dir  = string
    runtimes = list(string)
  }))
  default = {

    "lambda_utils" = {
      src_zip  = "src/artifacts/lambda_layers/lambda-utils-aws-lambda-layer-python3.11.zip"
      src_dir  = "src/lambda_utils/python"
      runtimes = ["python3.11"]
    }
  }
}

# ..................................................................... lambdas

variable "lambdas" {
  type = map(object({
    src_dir     = string
    ecr_image   = bool
    handler     = string
    name        = string
    trigger     = list(string)
    tags        = map(string)
    layers      = list(string)
    layers_arns = list(string)
    test_event  = string
  }))

  default = {
    "lambda_image_scale" = { #<-- same basename as trigger resource
      src_dir     = "src/lambda-image-scale",
      ecr_image   = true,
      handler     = "lambda.lambda_handler",
      name        = "lambda-image-scale", # lowercase + hyphens only
      trigger     = ["s3_event"],
      tags        = { Name = "S3 Event", Environment = "Dev" }
      layers      = [ lambda_utils ]
      layers_arns = []
      test_event  = "data/events/lambda_image_scale_test_event.json"
    }
  }
}

# ............................................................. dynamodb tables

variable "dynamodb_tables" {
  type = map(object({
    name     = string
    billing  = string
    read     = string
    write    = string
    hash_key = string
    ttl      = bool
    stream   = bool

    # Notice: attribute blocks inside aws_dynamodb_table resources are not defining
    # which cols you can use in your application.
    # They are defining the key schema for the table and indexes.
    # https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_AttributeDefinition.html

    attributes = map(string)
    indexes = map(object({
      hash_key  = string
      range_key = string
    }))
    cols = map(string)
    seed = string
    tags = map(string)
  }))

  default = {

    "users" = {
      name     = "user-table"
      billing  = "PAY_PER_REQUEST"
      read     = null
      write    = null
      hash_key = "email"
      ttl      = false
      stream   = false

      attributes = {
        email     = "S"
        type_     = "S"
        active_at = "N"
      }
      indexes = {
        "type-active-index" = {
          hash_key  = "type_"
          range_key = "active_at"
        }
      }
      cols = {
        email      = "S"
        first_name = "S"
        last_name  = "S"
        pass_hash  = "S"
        type_      = "S"
        created_at = "N"
        active_at  = "N"
      }
      seed = null
      tags = {
        Name        = "dynamoDB table",
        Environment = "Dev"
      }
    },

    "events" = {
      name     = "event-table"
      billing  = "PAY_PER_REQUEST"
      read     = null
      write    = null
      hash_key = "id"
      ttl      = true
      stream   = false

      attributes = {
        id         = "S"
        owner      = "S"
        created_at = "N"
      }
      indexes = {
        "owner-created-index" = {
          hash_key  = "owner"
          range_key = "created_at"
        }
      }
      cols = {
        id         = "S"
        owner      = "S"
        type_      = "S"
        enabled    = "N"
        targets    = "S"
        schedule   = "S"
        ttl        = "N"
        created_at = "N"
      }
      seed = null
      tags = {
        Name        = "dynamoDB table",
        Environment = "Dev"
      }
    },

    "prompts" = {
      name     = "prompts-table"
      billing  = "PAY_PER_REQUEST"
      read     = null
      write    = null
      hash_key = "id"
      ttl      = false
      stream   = false

      attributes = {
        id = "S"
      }
      indexes = {}
      cols = {
        id         = "S"
        res_id     = "S"
        task_      = "S"
        type_      = "S"
        via_       = "S"
        template   = "S"
        actors     = "S"
        author     = "S"
        created_at = "N"
      }
      seed = "data/seeders/prompts_table_seeder.json"
      tags = {
        Name        = "dynamoDB table",
        Environment = "Dev"
      }
    },

    "prompt-lookup" = {
      name     = "prompt-lookup-table"
      billing  = "PAY_PER_REQUEST"
      read     = null
      write    = null
      hash_key = "id"
      ttl      = false
      stream   = false

      attributes = {
        id    = "S"
        task_ = "S"
        type_ = "S"
      }
      indexes = {
        "task-type" = {
          hash_key  = "task_"
          range_key = "type_"
        }
      },
      cols = {
        id         = "S"
        prompt_ids = "S"
        task_      = "S"
        type_      = "S"
        via_       = "S"
      }
      seed = "data/seeders/prompt_lookup_table_seeder.json"
      tags = {
        Name        = "dynamoDB table",
        Environment = "Dev"
      }
    },

    "prompt-results" = {
      name     = "prompt-results-table"
      billing  = "PAY_PER_REQUEST"
      read     = null
      write    = null
      hash_key = "id"
      ttl      = true
      stream   = true

      attributes = {
        id = "S"
      }
      indexes = {}
      cols = {
        id         = "S"
        prompt_id  = "S"
        result     = "S"
        ttl        = "N"
        created_at = "N"
      }
      seed = null
      tags = {
        Name        = "dynamoDB table",
        Environment = "Dev"
      }
    },
  }
}

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

variable "project_dir" {
  type        = string
  default     = ".."
  description = "project base directory relative to the current directory (infra)"
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
      src_zip  = "artifacts/lambda_layers/lambda-utils-aws-lambda-layer-python3.11.zip"
      src_dir  = "src/lambda-utils/python"
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
      layers      = [ "lambda_utils" ]
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
  }
}

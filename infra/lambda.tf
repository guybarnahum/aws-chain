
# ...................................................................... lambda

# Create local lambdas from var.lambdas for iteration

locals {
  lambdas = { for id, l in var.lambdas : id => l }

  lambdas_zip_archive = {
    for id, l in var.lambdas : id => l if !l.ecr_image
    }

  lambdas_ecr_image = {
    for id, l in var.lambdas : id => l if l.ecr_image
    }
}

data "archive_file" "lambda_source_code" {
  for_each    = local.lambdas
    type        = "zip"
    source_dir  = each.value.src_dir
    output_path = "${each.value.src_dir}/../artifacts/${each.value.name}.zip"
    excludes    = ["__init__.py", "*.pyc", "*.zip","__pycache__","layers"]
}

resource aws_ecr_repository repo {
  for_each = local.lambdas_ecr_image
    name = "${each.value.name}-image"
}

resource null_resource ecr_image {
  for_each = local.lambdas_ecr_image

  triggers = {
    python_file = filebase64sha256("${each.value.src_dir}/lambda.py")
    req_file    = filebase64sha256("${each.value.src_dir}/requirements.txt")
    docker_file = filebase64sha256("${each.value.src_dir}/Dockerfile")
    install_file= filebase64sha256("${each.value.src_dir}/install.sh")
  }

  provisioner "local-exec" {
  command = join(" ", [ "/bin/bash +x",
                        "${each.value.src_dir}/install.sh",
                        "${aws_ecr_repository.repo[each.key].repository_url}:latest",
                        "${data.aws_caller_identity.current.account_id}",
                        "${data.aws_region.current.name}"
                        ])
  }
}

data "local_file" "sha256_digest" {
  for_each = local.lambdas_ecr_image
    depends_on = [null_resource.ecr_image]
    filename = "${each.value.src_dir}/sha256.digest"
}

#
# ecr cleanup : Expire all older images
#
resource "aws_ecr_lifecycle_policy" "lambda_ecr_image" {
  for_each = local.lambdas_ecr_image
    repository = aws_ecr_repository.repo[each.key].name
    policy = <<-EOT
    {
      "rules": [
          {
              "rulePriority": 1,
              "description": "Expire all older images, keep latest one by creation date",
              "selection": {
                  "tagStatus": "any",
                  "countType": "imageCountMoreThan",
                  "countNumber": 1
              },
              "action": {
                  "type": "expire"
              }
          }
      ]
    }
    EOT
}

#data docker_registry_image lambda_image {
#  for_each = local.lambdas_ecr_image
#    name = "${aws_ecr_repository.repo[each.key].repository_url}:latest"
#}
#data aws_ecr_image lambda_image {
#  for_each = local.lambdas_ecr_image
#    depends_on = [
#      null_resource.ecr_image
#    ]
#    repository_name = aws_ecr_repository.repo[each.key].repository_url
#    image_tag       = "latest"
#}

resource "aws_lambda_function" "lambda_function" {
  for_each = local.lambdas

    function_name = each.key
    filename      = each.value.ecr_image? null: data.archive_file.lambda_source_code[each.key].output_path
    image_uri     = each.value.ecr_image? "${aws_ecr_repository.repo[each.key].repository_url}:latest" : null
    package_type  = each.value.ecr_image? "Image" : "Zip"

    role          = aws_iam_role.lambda_role.arn
    runtime       = each.value.ecr_image? null : var.lambda_runtime
    handler       = each.value.ecr_image? null : each.value.handler
    timeout       = var.lambda_timeout
    memory_size   = var.lambda_memory
    architectures = var.lambda_architectures
    tags          = each.value.tags

    depends_on = [
      null_resource.ecr_image,
      data.archive_file.lambda_source_code,
      aws_lambda_layer_version.lambda_layer,
      aws_cloudwatch_log_group.lambda_log_group
    ]

    source_code_hash = each.value.ecr_image? trimspace(data.local_file.sha256_digest[each.key].content) : data.archive_file.lambda_source_code[each.key].output_base64sha256

    lifecycle {
      create_before_destroy = true
    }

    environment {
      variables = {
        CreatedBy = "Terraform"
      }
    }

    layers = each.value.ecr_image? null : local.lambda_layers_arns_list[each.key]

  # A list of arns, like the one below:
  #[
  #  "arn:aws:lambda:us-west-2:770693421928:layer:Klayers-p38-Pillow:6",
  #  "arn:aws:lambda:us-west-2:770693421928:layer:Klayers-p38-numpy:11",
  #  "arn:aws:lambda:us-west-2:770693421928:layer:Klayers-python38-scipy:1"
  #]
}

# Create log groups for each lambda

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  for_each          = local.lambdas
    name              = "/aws/lambda/${each.key}"
    retention_in_days = 7
    lifecycle {
      prevent_destroy = false
    }
}

resource "null_resource" "sam_metadata_aws_lambda_function" {
  for_each = local.lambdas_zip_archive
    triggers = {
      resource_name="aws_lambda_function.lambda_function[\"${each.key}\"]"
      resource_type= "ZIP_LAMBDA_FUNCTION"
      original_source_code = data.archive_file.lambda_source_code[each.key].source_dir
      built_output_path    = data.archive_file.lambda_source_code[each.key].output_path
  }
}

# .......................................................................... s3

# filtering lambdas by s3 trigger event

locals {
  s3_lambdas = {
    for id, l in var.lambdas : id => l if contains(l.trigger, "s3_event")
  }
}

# Creating s3 resource for invoking to lambda function

resource "aws_s3_bucket" "lambda_s3_bucket" {
  for_each = local.s3_lambdas
    bucket   = "${each.value.name}-bucket-us-west-2"
    tags     = each.value.tags
}

resource "aws_s3_bucket_public_access_block" "public_access_block" {
  for_each = local.s3_lambdas
    bucket   = aws_s3_bucket.lambda_s3_bucket[each.key].id

    block_public_acls   = false
    block_public_policy = false
    ignore_public_acls  = false
}

resource "aws_s3_bucket_ownership_controls" "ownership_controls" {
  for_each = local.s3_lambdas
    bucket   = aws_s3_bucket.lambda_s3_bucket[each.key].id
    rule {
      object_ownership = "BucketOwnerPreferred"
    }
}

resource "aws_s3_bucket_acl" "s3_bucket_acl" {
  for_each = local.s3_lambdas
    depends_on = [
      aws_s3_bucket_public_access_block.public_access_block,
      aws_s3_bucket_ownership_controls.ownership_controls
    ]
    bucket = aws_s3_bucket.lambda_s3_bucket[each.key].id
    acl    = "public-read"
}

data "aws_iam_policy_document" "s3_allow_access_policy_document" {
  for_each = local.s3_lambdas
    statement {
      effect = "Allow"

      actions = [
        "s3:Get*",
        "s3:List*",
      ]

      resources = ["arn:aws:s3:::${each.value.name}-bucket-us-west-2/*"]

      sid = "PublicReadGetObject"
      principals {
        type        = "*"
        identifiers = ["*"]
      }
    }
}

resource "aws_s3_bucket_policy" "s3_allow_access_policy" {
  for_each = local.s3_lambdas
    bucket   = aws_s3_bucket.lambda_s3_bucket[each.key].id
    policy   = data.aws_iam_policy_document.s3_allow_access_policy_document[each.key].json
}

# Adding S3 bucket as trigger to my lambda and giving the permissions

resource "aws_s3_bucket_notification" "aws-lambda-trigger" {
  for_each = local.s3_lambdas
    bucket   = aws_s3_bucket.lambda_s3_bucket[each.key].id

    lambda_function {
      lambda_function_arn = aws_lambda_function.lambda_function[each.key].arn
      events              = ["s3:ObjectCreated:*"]
      #filter_prefix       = "file-prefix"
      #filter_suffix       = "jpg"
    }
}

resource "aws_s3_object" "input_directory" {
  for_each = local.s3_lambdas
    depends_on = [
      aws_s3_bucket_acl.s3_bucket_acl
    ]
    bucket       = aws_s3_bucket.lambda_s3_bucket[each.key].id
    acl          = "public-read-write"
    key          = "input/"
    content_type = "application/x-directory"
}

resource "aws_s3_object" "output_directory" {
  for_each = local.s3_lambdas
    depends_on = [
      aws_s3_bucket_acl.s3_bucket_acl
    ]
    bucket       = aws_s3_bucket.lambda_s3_bucket[each.key].id
    acl          = "public-read-write"
    key          = "output/"
    content_type = "application/x-directory"
}

resource "aws_lambda_permission" "lambda_s3_permission" {
  for_each      = local.s3_lambdas
    statement_id  = "AllowS3Invoke"
    action        = "lambda:InvokeFunction"
    function_name = each.key
    principal     = "s3.amazonaws.com"
    source_arn    = "arn:aws:s3:::${aws_s3_bucket.lambda_s3_bucket[each.key].id}"
}


# .......................................................................... cw

# filtering lambdas by cloudwatch trigger event

locals {
  cw_lambdas = {
    for id, l in var.lambdas : id => l if contains(l.trigger, "cw_event")
  }
}

resource "aws_cloudwatch_event_rule" "hourly_event_rule" {
  name                = "run-lambda-function"
  description         = "Schedule lambda function"
  schedule_expression = "rate(1 hour)"
  #is_enabled = lookup
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  for_each      = local.cw_lambdas
    statement_id  = "AllowExecutionFromCloudWatch"
    action        = "lambda:InvokeFunction"
    function_name = each.key
    principal     = "events.amazonaws.com"
    source_arn    = aws_cloudwatch_event_rule.hourly_event_rule.arn
}

resource "aws_cloudwatch_event_target" "lambda-function-target" {
  for_each  = local.cw_lambdas
    target_id = "lambda-function-target"
    rule      = aws_cloudwatch_event_rule.hourly_event_rule.name
    arn       = aws_lambda_function.lambda_function[each.key].arn
}

# ................................................... lambda shared test events
#
# These test events populate the aws lambda console
# https://us-west-2.console.aws.amazon.com/lambda/home
#
# Notice: Hack: Unpublished : Subject to change!
# See https://stackoverflow.com/questions/60329800/how-can-i-create-a-lambda-event-template-via-terraform
# And https://docs.aws.amazon.com/lambda/latest/dg/testing-functions.html
#

resource "aws_schemas_schema" "lambda_test_events" {
  for_each = local.lambdas
    name          = "_${aws_lambda_function.lambda_function[each.key].function_name}-schema"
    registry_name = "lambda-testevent-schemas"
    description   = "The schema definition for shared test events"
    type          = "OpenApi3" # <-- only valid option
    content       = file(each.value.test_event)
}

# ............................................................. dynamodb stream

# filtering lambdas by dynamodb-stream trigger event

locals {
  dynamodb_stream_lambdas = {
    for id, l in var.lambdas : id => l if contains(l.trigger, "dynamodb_stream")
  }
}

resource "aws_lambda_event_source_mapping" "lambda-function-target" {
  for_each          = local.dynamodb_stream_lambdas
    event_source_arn  = aws_dynamodb_table.dynamodb_table["${each.key}"].stream_arn
    function_name     = aws_lambda_function.lambda_function["${each.key}"].arn
    starting_position = "LATEST"
}

# ..................................................................... outputs

output "lambda_layers_pip_installs_list" {
  description = "Lambda Layers pip installs list"
  value       = var.enable_outputs ? local.lambda_layers_pip_install : null
}

output "lambda_layers_archives_list" {
  description = "Lambda Layers archives list"
  value       = var.enable_outputs ? local.lambda_layer_archives : null
}

output "lambda_layers_arns_list" {
  description = "Lambda Layers arns list"
  value       = var.enable_outputs ? local.lambda_layers_arns_list : null
}

output "dynamodb_stream_lambdas_list" {
  description = "Lambda dynamodb streams list"
  value       = var.enable_outputs ? local.dynamodb_stream_lambdas : null
}

# ............................................................... lambda layers

locals {
  lambda_layers = {
    for id, ll in var.lambda_layers : id => ll
  }

  lambda_layers_pip_install = {
    for id, ll in var.lambda_layers : id => ll
    if fileexists("${var.project_dir}/${ll.src_dir}/requirements.txt")
  }

  lambda_layer_archives = {
    for id, ll in var.lambda_layers : id => ll
    if ll.src_dir != ""
  }

  lambda_layers_arns_list = {
    for id, l in var.lambdas : id => setunion(
      [
        for ll in l.layers : "${aws_lambda_layer_version.lambda_layer[ll].arn}"
      ],
    l.layers_arns)
  }
}

resource "null_resource" "pip_install" {

  for_each = local.lambda_layers_pip_install
    triggers = {
      req_file      = filebase64sha256("${var.project_dir}/${each.value.src_dir}/requirements.txt")
      install_file  = filebase64sha256("${var.project_dir}/${each.value.src_dir}/pip_install.sh")
    }

    # pip installs from src_dir/requirements.txt into src_dir/python
    provisioner "local-exec" {
      command = "/bin/bash +x ${var.project_dir}/${each.value.src_dir}pip_install.sh"
    }
}

data "archive_file" "data_backup" {
  for_each    = local.lambda_layer_archives
  type        = "zip"
  source_dir  = "${var.project_dir}/${each.value.src_dir}"
  output_path = "${var.project_dir}/${each.value.src_zip}"
  excludes = [
    "__pycache__",
    "requirements.txt",
    ".gitignore",
    "pip_install.sh"
  ]

  depends_on = [
    null_resource.pip_install
  ]
}

resource "aws_lambda_layer_version" "lambda_layer" {
  for_each            = local.lambda_layers
    layer_name          = each.key
    filename            = "${var.project_dir}/${each.value.src_zip}"
    source_code_hash    = fileexists("${var.project_dir}/${each.value.src_zip}")? filebase64sha256("${var.project_dir}/${each.value.src_zip}"):0
    compatible_runtimes = each.value.runtimes

    depends_on = [
      data.archive_file.data_backup
    ]
}

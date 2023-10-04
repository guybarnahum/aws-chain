terraform {
  required_version = ">= 0.13.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.19"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.9.1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 2.0"
    }
    klayers = {
      version = "~> 1.0.0"
      source  = "ldcorentin/klayer"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

# ................................................................. credentials

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  time = {
    now          = time_static.now.unix
    now_readable = formatdate("YYYY-MM-DD_hh-mm-ss", time_static.now.rfc3339)
  }
}

resource "time_static" "now" {}

output "time" {
  description = "current time"
  value       = local.time
}

locals {
  # Auto-load global variables
  global_vars = read_terragrunt_config(find_in_parent_folders("globals.hcl"))

  # Load project-specific config
  raw_config = yamldecode(file("${get_terragrunt_dir()}/config.yaml"))
  cfg        = local.raw_config.config

  # Extract the required variables for easy access
  aws_region = local.global_vars.locals.aws_region

  # Default tags for resources
  default_tags      = try(yamldecode(file(find_in_parent_folders("resource-tags.yaml"))), {})
  override_tags_yaml = try(yamldecode(file("${get_terragrunt_dir()}/tags.yaml")), {})
  tags               = merge(local.default_tags, local.override_tags_yaml)
}

# Generate default versions.tf
generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
  terraform {
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = ">= 5.50.0"
      }
  }
}
EOF
}

# Generate default AWS provider block

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
  default_tags {
    tags = ${jsonencode(local.tags)}
  }
}

EOF
}

remote_state {
  backend = "s3"
  config = {
    encrypt        = true
    bucket         = "cc-appstream2-image-builder-${get_env("ACCOUNT_ID", "")}-${local.aws_region}-tf-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    dynamodb_table = "cc-appstream2-image-builder-tf-locks"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Merge *both* globals.hcl and config.yaml into every module:
inputs = merge(
  local.global_vars.locals,
  local.cfg,
  {
    # if you want to override or add any extra Terragrunt‐only inputs:
    extra_flag = true
  }
)


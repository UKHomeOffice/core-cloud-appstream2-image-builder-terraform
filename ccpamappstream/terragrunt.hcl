# ccpamappstream/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  # path_relative_from_include() returns "ccpamappstream"
  source = "../modules/appstream2-automation-infra"
}

locals {
  # Load the top-level config.yaml
  config_all = yamldecode(file(find_in_parent_folders("config.yaml")))
  # Pull out the `config:` map
  account = lookup(local.config_all, "config", {})

  # Grab aws_region from globals.hcl via root.hcl
  aws_region = read_terragrunt_config(find_in_parent_folders("globals.hcl")).locals.aws_region

  # Environment name (folder name)
  env = basename(path_relative_from_include())
}

inputs = {
  # Core settings
  region             = local.aws_region
  project_name       = local.account.project_name
  base_image_name    = local.account.base_image_name
  state_machine_name = "appstream-rockylinux-build-${local.env}"

  # Where to find your SSM doc & SFN definition
  doc_source             = "${get_repo_root()}/ssm/AppStreamImageAssistant-automation.json"
  stepfn_definition_file = "${get_repo_root()}/modules/appstream2-automation-infra/stepfunction_definition.json"

  # Networking for the ImageBuilder
  vpc_id            = local.account.vpc_id
  subnet_id         = local.account.subnet_id
  security_group_id = local.account.security_group_id

  # Downstream accounts to share with
  live_account_id    = local.account.live_account_id
  prelive_account_id = local.account.prelive_account_id
}

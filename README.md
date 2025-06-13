# core-cloud-appstream2-image-builder-terraform

# AppStream 2.0 Rocky Linux Image Build Automation

This repository contains Terraform/Terragrunt configurations, AWS Step Functions, SSM Automation documents, and a GitHub Actions workflow to fully automate the process of building a custom Rocky Linux AppStream 2.0 image and sharing it with downstream AWS accounts.

## Repository Structure

```
.github/
└── workflows/
    └── appstream2-image-build.yaml   # CI/CD workflow definition

ccpamappstream/
└── terragrunt.hcl                    # Terragrunt config for root module

config.yaml                           # Project-specific variable overrides
globals.hcl                           # Global Terragrunt settings (region, tags)
root.hcl                              # Root Terragrunt configuration (provider, remote state)

modules/
└── appstream2-automation-infra/      # Core automation infrastructure module
    ├── main.tf                       # IAM roles, SSM document, Step Functions SM
    ├── variables.tf                  # Module input definitions
    ├── outputs.tf                    # Module outputs (state machine ARN, etc.)
    ├── stepfunction_definition.json  # Standalone SFN definition in pure JSON
    └── README.md                     # Module-specific documentation

ssm/
└── AppStreamImageAssistant-automation.json  # SSM Automation document for package install & image build
```

## Prerequisites

* **AWS Account** with the following:

  * **OIDC Provider** configured to trust `token.actions.githubusercontent.com` for your GitHub Org/Repo
  * IAM roles:

    * `cc-appstream2-terragrunt-plan-role` (for planning) and `cc-appstream2-terragrunt-apply-role` (for applying), each with a trust policy allowing `sts:AssumeRoleWithWebIdentity` from GitHub Actions
    * Instance profile for AppStream Image Builder with AmazonSSMManagedInstanceCore
  * VPC, subnets, and security groups for AppStream Image Builder

* **GitHub Repository** configured with:

  * [OIDC authentication](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
  * Repository or organization settings to allow workflows to request the roles above
  * Secrets (just for non-OIDC values):

    * `SUBNET_ID`: VPC subnet for launching the Image Builder
    * `SECURITY_GROUP_ID`: Security group to attach to the Image Builder
    * `LIVE_ACCOUNT_ID`: AWS account ID for sharing the image (live)
    * `PRELIVE_ACCOUNT_ID`: AWS account ID for sharing the image (pre-live)

* **Local Tooling** (for manual development):

  * Terraform v1.9.3
  * Terragrunt v0.59.6
  * AWS CLI v2
  * `jq`, `yq` for YAML/JSON parsing

## Configuration

### config.yaml

Define your project and environment-specific values here:

```yaml
config:
  project_name: cc-pam
  base_image_name: AppStream-RockyLinux8-05-30-2025
  live_account_id: "4799767xxxxx"
  prelive_account_id: "9005119xxxxx"
  doc_source:                             # Path to SSM doc (optional override)
  vpc_id: vpc-05xs5f6e0xxxxxxx
  subnet_id: subnet-026bxxb538xxxxx
  security_group_id: sg-03xxxx4b97d81a336
  accounts:
    account_id: "8795662xxxx"           # Account for Terragrunt assume-role
```

### globals.hcl and root.hcl

* `globals.hcl` holds global variables (region, tags).
* `root.hcl` generates provider and remote state blocks and merges in `config.yaml` values.

## Infrastructure Deployment (Terragrunt)

In the **ccpamappstream/** directory:

```bash
cd ccpamappstream
terragrunt init
terragrunt run-all plan        # preview changes
terragrunt run-all apply        # deploy IAM roles, SSM doc, Step Function
```

This will provision:

1. **IAM Roles & Policies** for Step Functions and EC2 (Image Builder)
2. **SSM Automation Document** to install packages and build the image
3. **AWS Step Functions** State Machine to orchestrate the end-to-end build

## Automation Module Details

See `modules/appstream2-automation-infra/README.md` for module-specific docs, including:

* **SSM Automation** to install packages and run `AppStreamImageAssistant`
* **Step Functions** JSON definition

## CI/CD Workflow

The GitHub Actions workflow **.github/workflows/appstream2-image-build.yaml** does the following:

1. **infra** job:

   * Checks out code
   * Installs `yq`, loads `config.yaml` values into environment variables
   * Assumes a Terragrunt plan role
   * Runs `terragrunt run-all plan` and `apply` to deploy infra
2. **build** job (on `main` branch):

   * Checks out code
   * Installs `yq`, loads account ID
   * Assumes AWS credentials
   * Installs Terragrunt & Terraform via `gruntwork-io/terragrunt-action`
   * Reads the Step Function ARN from Terragrunt outputs
   * Starts Step Function execution with a JSON payload
   * Waits (with built-in waiter + failure debug) for execution success
   * Verifies the final AppStream image status
   * Confirms image sharing permissions
   * Prints a cleanup summary

### Triggering the Workflow

* **Manual dispatch** with `builder_name` and `image_name` inputs
* **On push to `main`**
* **On PR** against `main` (optional dry-run)

## Usage

To build and share a new AppStream image:

1. Update `config.yaml` as needed.
2. `git checkout -b feature/your-feature`
3. Commit changes and push.
4. Open a PR or merge to `main`.
5. (If manual) Trigger the workflow via GitHub UI, supplying:

   * **builder\_name**: e.g. `cc-pam-rocky-2025-06-13`
   * **image\_name**: e.g. `cc-pam-rocky-linux-2025-06-13`

Monitor actions logs for end-to-end progress.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) (if applicable) for guidelines on reporting issues or submitting enhancements.

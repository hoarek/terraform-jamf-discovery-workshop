###############################################################################
# Root provider requirements
#
# Terraform 1.14 is the floor because modules/configuration-jamf-security-cloud-
# all-services drives jamfplatform_security_cloud_activation_profile_deploy from a
# lifecycle { action_trigger }, and action blocks do not exist before 1.14.
#
# The jamfplatform version constraint is "~> 0.29": stable 0.29.0 shipped on
# 2026-09-04 (provider PR #371), so the exact-pin workaround for pre-release
# selection is no longer needed. Note: "~> 0.29" (two-part) allows any release
# >= 0.29.0 up to but not including 1.0 — it resolved to 0.30.0 and validate
# passed cleanly, so 0.30.0 is what the lockfile records. Use "~> 0.29.0"
# (three-part) if you need to constrain to the 0.29.x patch line only.
#
# See https://registry.terraform.io/providers/Jamf-Concepts/jamfplatform/latest/docs/guides/platform-api-ga
###############################################################################

terraform {
  required_version = ">= 1.14"
  required_providers {
    jamfplatform = {
      source  = "Jamf-Concepts/jamfplatform"
      version = "~> 0.29"
    }
  }
}

###############################################################################
# Jamf Platform provider root configuration
#
# base_url is the GA gateway host, https://{region}.api.jamfcloud.com. Host only:
# the gateway serves the token endpoint and every API namespace at the root, and a
# request carrying the beta's /api path segment gets a bare 404 page not found
# rather than a JSON error.
#
# environment_id and tenant_id are mutually exclusive — an API integration targets
# one or the other, and setting both fails at configure time with Conflicting API
# Integration Scope. Both are passed as null when their variable is empty so that
# whichever one the operator supplied is the only one the provider sees. Supplying
# the identifier that does not match how the integration was registered is refused
# with 403 OWNERSHIP_FORBIDDEN even when both belong to the same customer, so this
# is a choice to get right rather than two spellings of the same thing.
#
# Setting neither leaves the provider organization-scoped, which is what the
# jamfplatform_account_* family needs and no module in this repo uses. The
# validation on jamfplatform_environment_id rejects that case, because reaching it
# here would mean the wizard collected no scope at all.
###############################################################################

provider "jamfplatform" {
  base_url                = var.jamfplatform_base_url
  client_id               = var.jamfplatform_client_id
  client_secret           = var.jamfplatform_client_secret
  environment_id          = var.jamfplatform_environment_id != "" ? var.jamfplatform_environment_id : null
  tenant_id               = var.jamfplatform_tenant_id != "" ? var.jamfplatform_tenant_id : null
  min_request_interval_ms = var.min_request_interval_ms
}

provider "jamfplatform" {
  alias                   = "jpro"
  base_url                = var.jamfplatform_base_url
  client_id               = var.jamfplatform_client_id
  client_secret           = var.jamfplatform_client_secret
  environment_id          = var.jamfplatform_environment_id != "" ? var.jamfplatform_environment_id : null
  tenant_id               = var.jamfplatform_tenant_id != "" ? var.jamfplatform_tenant_id : null
  min_request_interval_ms = var.min_request_interval_ms
}

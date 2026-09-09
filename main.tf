###############################################################################
# Discovery Workshop root module
#
# Deployed by configs/discovery-workshop.json in jamf/modular_onboarder. The
# wizard writes every variable in variables.tf into a tfvars file, dispatches
# .github/workflows/terraform-platform.yml, and polls for its artifacts.
###############################################################################

# The tenant's own Jamf Pro console URL. The upstream public repo collects this as
# var.jamfpro_instance_url; reading it removes a wizard field and one more thing a
# PSE can mistype. The variable is kept as an override so this repo stays mergeable
# upstream.
data "jamfplatform_pro_jamf_pro_server_url" "current" {}

locals {
  jamfpro_instance_url = trimsuffix(
    var.jamfpro_instance_url != "" ? var.jamfpro_instance_url : data.jamfplatform_pro_jamf_pro_server_url.current.url,
    "/"
  )

  # jamfplatform_pro_sso_settings is a singleton: its ID is always "singleton", so
  # two modules cannot co-manage it. Deriving all four branches from one string
  # makes that structurally impossible, which three independent include_idp_*
  # booleans would not. Exactly one of these is true for any valid idp_choice.
  idp_okta      = var.idp_choice == "okta"
  idp_microsoft = var.idp_choice == "microsoft"
  idp_none      = var.idp_choice == "none"

  # 'none' still enables Jamf Account admin SSO, because wizard page 2 tells the
  # customer it will. The identity modules cover the same ground with OIDC_WITH_SAML,
  # so this is the OIDC-only fallback rather than an addition to them.
  enable_admin_sso_only = local.idp_none || var.include_jamf_pro_admin_sso
}

###############################################################################
# Management foundation
###############################################################################

module "onboarder-management-macOS" {
  count  = var.include_onboarder_management_macOS == true ? 1 : 0
  source = "./modules/onboarder-management-macOS"
  providers = {
    jamfplatform.jpro = jamfplatform.jpro
  }
}

module "onboarder-management-mobile" {
  count  = var.include_onboarder_management_mobile == true ? 1 : 0
  source = "./modules/onboarder-management-mobile"
  providers = {
    jamfplatform.jpro = jamfplatform.jpro
  }
}

module "endpoint-security-macOS-filevault" {
  count                      = var.include_filevault == true ? 1 : 0
  source                     = "./modules/endpoint-security-macOS-filevault"
  jamfplatform_base_url      = var.jamfplatform_base_url
  jamfplatform_client_id     = var.jamfplatform_client_id
  jamfplatform_client_secret = var.jamfplatform_client_secret
  providers = {
    jamfplatform.jpro = jamfplatform.jpro
  }
}

###############################################################################
# Apple service tokens
#
# No include_ flag, deliberately. Each resource inside is gated on its own token
# being non-empty, so the module is always instantiated and the Automated Device
# Enrollment public key data source is readable on the first run — the run that
# has no token yet, because the operator needs the public key to get one from
# Apple. See modules/configuration-apple-service-tokens/README.md.
###############################################################################

module "configuration-apple-service-tokens" {
  source = "./modules/configuration-apple-service-tokens"

  device_enrollment_token_content    = var.device_enrollment_token_content
  device_enrollment_token_wo_version = var.device_enrollment_token_wo_version

  volume_purchasing_service_token_content    = var.volume_purchasing_service_token_content
  volume_purchasing_service_token_wo_version = var.volume_purchasing_service_token_wo_version

  providers = {
    jamfplatform.jpro = jamfplatform.jpro
  }
}

###############################################################################
# Jamf Security Cloud
#
# Both modules reach Jamf Security Cloud through the same Platform API gateway and
# the same integration as the Jamf Pro modules, as the jamfplatform_security_cloud_*
# family. The separate Jamf-Concepts/jsctfprovider provider is gone, and with it the
# second credential set and the jsc.jsc alias these two used to be passed.
###############################################################################

module "configuration-jamf-security-cloud-jamf-pro" {
  count  = var.include_jsc_uemc == true ? 1 : 0
  source = "./modules/configuration-jamf-security-cloud-jamf-pro"

  sync_refresh_interval_minutes     = var.jsc_sync_refresh_interval_minutes
  device_risk_uem_signaling_enabled = var.jsc_device_risk_uem_signaling_enabled

  providers = {
    jamfplatform.jpro = jamfplatform.jpro
  }
}

module "configuration-jamf-security-cloud-all-services" {
  count  = var.include_jsc_all_services == true ? 1 : 0
  source = "./modules/configuration-jamf-security-cloud-all-services"

  providers = {
    jamfplatform.jpro = jamfplatform.jpro
  }
}

###############################################################################
# Jamf Protect
###############################################################################

module "configuration-jamf-pro-jamf-protect" {
  count                       = var.include_jamf_protect_trial_kickstart == true ? 1 : 0
  source                      = "./modules/configuration-jamf-pro-jamf-protect"
  jamfplatform_base_url       = var.jamfplatform_base_url
  jamfplatform_client_id      = var.jamfplatform_client_id
  jamfplatform_client_secret  = var.jamfplatform_client_secret
  jamfprotect_url             = var.jamfprotect_url
  jamfprotect_client_id       = var.jamfprotect_client_id
  jamfprotect_client_password = var.jamfprotect_client_password
  providers = {
    jamfplatform.jpro = jamfplatform.jpro
  }
}

###############################################################################
# Identity — Jamf Pro SSO singleton
#
# Exactly one of the four blocks below is active for any valid idp_choice.
###############################################################################

module "identity-jamf-pro-okta" {
  count  = local.idp_okta && !var.include_jamf_pro_admin_sso ? 1 : 0
  source = "./modules/identity-jamf-pro-okta"

  okta_sso_metadata_url         = var.okta_sso_metadata_url
  okta_service_account_username = var.okta_service_account_username
  okta_ldap_password            = var.okta_ldap_password
  idp_shortname                 = var.idp_shortname

  providers = {
    jamfplatform.jpro = jamfplatform.jpro
  }
}

module "identity-jamf-pro-microsoft-entra" {
  count  = local.idp_microsoft && !var.include_jamf_pro_admin_sso ? 1 : 0
  source = "./modules/identity-jamf-pro-microsoft-entra"

  entra_sso_metadata_url                  = var.entra_sso_metadata_url
  idp_shortname                           = var.idp_shortname
  entra_configure_cloud_identity_provider = var.entra_configure_cloud_identity_provider

  providers = {
    jamfplatform.jpro = jamfplatform.jpro
  }
}

# OIDC only. Used when idp_choice is 'none', or when include_jamf_pro_admin_sso is
# forced on — in which case it takes precedence over the identity modules above,
# because all three write the same singleton.
module "configuration-jamf-pro-admin-sso" {
  count                      = local.enable_admin_sso_only ? 1 : 0
  source                     = "./modules/configuration-jamf-pro-admin-sso"
  jamfplatform_base_url      = var.jamfplatform_base_url
  jamfplatform_client_id     = var.jamfplatform_client_id
  jamfplatform_client_secret = var.jamfplatform_client_secret
  providers = {
    jamfplatform.jpro = jamfplatform.jpro
  }
}

###############################################################################
# Identity — device-side payloads
#
# All three default off and configs/discovery-workshop.json does not turn them on.
# Vendored from the public repo so a future config can, without another port.
###############################################################################

# WARNING: the bundled .mobileconfig has a Jamf demo Okta tenant and SCEP URL
# hardcoded in it, and the module takes no Okta inputs to override them with.
# Enabling this against a customer tenant deploys a profile pointing at the wrong
# Okta org. See README.md, Open items.
module "management-macOS-SSOe-Okta" {
  count                      = var.include_ssoe_okta == true ? 1 : 0
  source                     = "./modules/management-macOS-SSOe-Okta"
  jamfplatform_base_url      = var.jamfplatform_base_url
  jamfplatform_client_id     = var.jamfplatform_client_id
  jamfplatform_client_secret = var.jamfplatform_client_secret
  providers = {
    jamfplatform.jpro = jamfplatform.jpro
  }
}

module "management-okta-psso" {
  count                      = var.include_okta_psso == true ? 1 : 0
  source                     = "./modules/management-okta-psso"
  jamfplatform_base_url      = var.jamfplatform_base_url
  jamfplatform_client_id     = var.jamfplatform_client_id
  jamfplatform_client_secret = var.jamfplatform_client_secret
  okta_short_url             = var.okta_short_url
  okta_org_name              = var.okta_org_name
  okta_scep_url              = var.okta_scep_url
  okta_psso_client           = var.okta_psso_client
  okta_scep_username         = var.okta_scep_username
  okta_scep_password         = var.okta_scep_password
  providers = {
    jamfplatform.jpro = jamfplatform.jpro
  }
}

module "management-microsoft-psso" {
  count                      = var.include_microsoft_psso == true ? 1 : 0
  source                     = "./modules/management-microsoft-psso"
  jamfplatform_base_url      = var.jamfplatform_base_url
  jamfplatform_client_id     = var.jamfplatform_client_id
  jamfplatform_client_secret = var.jamfplatform_client_secret
  providers = {
    jamfplatform.jpro = jamfplatform.jpro
  }
}

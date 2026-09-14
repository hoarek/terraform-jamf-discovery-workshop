## Call Terraform provider
terraform {
  required_providers {
    jamfplatform = {
      source                = "jamf/jamfplatform"
      version               = "0.32.0"
      configuration_aliases = [jamfplatform.jpro]
    }
  }
}

# Supplies the tenant's own Jamf Pro URL, which the SAML EntityID is built from.
# The MSP module took this as var.jamfpro_instance_url.
data "jamfplatform_pro_jamf_pro_server_url" "current" {}

# Failover URL. regeneration_trigger is omitted, so later applies adopt the existing URL
# rather than rotating it. Surfaced as a sensitive output — it is the way back into the
# console if SSO misbehaves, so a workshop should capture it before anyone signs out.
resource "jamfplatform_pro_sso_failover_url" "entra" {}

# Jamf Pro SSO settings. Singleton: exactly one of the identity-jamf-pro-* modules may be
# active per apply, which is why the root gates them on a single idp_choice string.
resource "jamfplatform_pro_sso_settings" "entra" {
  sso_enabled        = true
  configuration_type = "OIDC_WITH_SAML"

  sso_for_enrollment_enabled                           = true
  sso_for_macos_self_service_enabled                   = true
  enrollment_sso_for_account_driven_enrollment_enabled = false
  group_enrollment_access_enabled                      = false
  sso_bypass_allowed                                   = false

  # OIDC half — Jamf Account sign-in for admins. Identical to the Okta module and to the
  # standalone configuration-jamf-pro-admin-sso module, both of which are mutually
  # exclusive with this one.
  oidc_settings = {
    user_mapping                     = "EMAIL"
    username_attribute_claim_mapping = "EMAIL"
    jamf_id_authentication_enabled   = true
  }

  # SAML half, for enrolment and Self Service SSO against Entra ID.
  #
  # metadata_file_name and federation_metadata_file are omitted rather than set to "":
  # the provider documents URL and FILE as mutually exclusive branches. MSP set them to
  # empty strings only because the old provider required every field in the block.
  saml_settings = {
    idp_provider_type = "AZURE"
    metadata_source   = "URL"
    idp_url           = var.entra_sso_metadata_url
    entity_id         = "${local.jamf_pro_url}/saml/metadata"

    # Microsoft's groups claim URI, not the xmlsoap one Okta emits.
    group_attribute_name = "http://schemas.microsoft.com/ws/2008/06/identity/claims/groups"

    # Unlike Okta, Entra can match on a named short-name claim. All three of these move
    # together: MSP couples them the same way.
    user_mapping           = local.entra_use_shortname ? "USERNAME" : "EMAIL"
    user_attribute_enabled = local.entra_use_shortname
    user_attribute_name    = local.entra_use_shortname ? var.idp_shortname : null

    token_expiration_disabled = true
    session_timeout           = 480
  }

  # Generated rather than uploaded. Replaces MSP's separate jamfpro_sso_certificate
  # resource, and is idempotent: the provider does not regenerate on re-apply, so existing
  # IdP trust is not invalidated.
  signing_certificate = {
    setup_type = "GENERATED"
  }

  # Present but empty, matching MSP. Populate hosts with the Entra login host if
  # Account-Driven Enrollment SSO is enabled later.
  enrollment_sso_config = {
    hosts = []
  }
}

# Directory integration.
#
# Not a port: msp-services-onboarding-tf leaves this as a manual wizard step, because
# deploymenttheory/jamfpro had no resource for it. jamfplatform does, so the module
# creates the connection instead of telling the operator to click through it.
#
# One manual step remains, and it cannot be automated: after the first apply, an Entra
# global administrator must grant consent in Settings > Cloud Identity Provider in the
# Jamf Pro console. Group lookups return nothing until they do.
resource "jamfplatform_pro_cloud_identity_provider" "entra" {
  count = var.entra_configure_cloud_identity_provider ? 1 : 0

  display_name  = "Microsoft Entra ID"
  provider_name = "ENTRA_ID"

  entra_id = {
    # Derived from the federation metadata URL. Changing it forces replacement, so an
    # operator who pastes a different tenant's metadata URL on a re-run gets a
    # replacement rather than a silent no-op.
    tenant_id = local.entra_tenant_id
    enabled   = true

    search_timeout                              = 30
    membership_calculation_optimization_enabled = true
    transitive_membership_enabled               = false
    transitive_directory_membership_enabled     = false
  }

  timeouts = {
    create = "10m"
    update = "10m"
  }
}

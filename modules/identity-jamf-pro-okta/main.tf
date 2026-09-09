## Call Terraform provider
terraform {
  required_providers {
    jamfplatform = {
      source                = "Jamf-Concepts/jamfplatform"
      version               = "~> 0.29"
      configuration_aliases = [jamfplatform.jpro]
    }
  }
}

# Supplies the tenant's own Jamf Pro URL, which the SAML EntityID is built from.
# The MSP module took this as var.jamfpro_instance_url; reading it removes a wizard
# field and one more thing a PSE can mistype.
data "jamfplatform_pro_jamf_pro_server_url" "current" {}

# Failover URL. Creating this resource adopts the tenant's current URL; because
# regeneration_trigger is omitted, later applies leave it alone rather than rotating it
# on every run. Surfaced as a sensitive output — it is the way back into the console if
# SSO misbehaves, so a workshop should capture it before anyone signs out.
resource "jamfplatform_pro_sso_failover_url" "okta" {}

# Jamf Pro SSO settings. Singleton: exactly one of the identity-jamf-pro-* modules may
# be active per apply, which is why the root gates them on a single idp_choice string.
resource "jamfplatform_pro_sso_settings" "okta" {
  sso_enabled        = true
  configuration_type = "OIDC_WITH_SAML"

  sso_for_enrollment_enabled                           = true
  sso_for_macos_self_service_enabled                   = true
  enrollment_sso_for_account_driven_enrollment_enabled = false
  group_enrollment_access_enabled                      = false
  sso_bypass_allowed                                   = false

  # OIDC half. This is what makes Jamf Account sign-in work for admins, and is the same
  # configuration the standalone configuration-jamf-pro-admin-sso module applies. That
  # module is mutually exclusive with this one.
  oidc_settings = {
    user_mapping                     = "EMAIL"
    username_attribute_claim_mapping = "EMAIL"
    jamf_id_authentication_enabled   = true
  }

  # SAML half, for enrolment and Self Service SSO against Okta.
  #
  # metadata_file_name and federation_metadata_file are deliberately omitted rather than
  # set to "". The provider documents URL and FILE as mutually exclusive branches; the
  # MSP module set them to empty strings only because the old provider required every
  # field in the block to be present.
  saml_settings = {
    idp_provider_type = "OKTA"
    metadata_source   = "URL"
    idp_url           = var.okta_sso_metadata_url
    entity_id         = "${local.jamf_pro_url}/saml/metadata"

    group_attribute_name = "http://schemas.xmlsoap.org/claims/Group"

    user_mapping           = local.okta_use_shortname ? "USERNAME" : "EMAIL"
    user_attribute_enabled = false

    token_expiration_disabled = true
    session_timeout           = 480
  }

  # Generated rather than uploaded. This replaces the separate jamfpro_sso_certificate
  # resource in MSP, and is idempotent: the provider does not regenerate on re-apply, so
  # the certificate does not churn and existing IdP trust is not invalidated.
  signing_certificate = {
    setup_type = "GENERATED"
  }

  # Present but empty, matching MSP. Populate hosts with the Okta tenant if
  # Account-Driven Enrollment SSO is enabled later.
  enrollment_sso_config = {
    hosts = []
  }
}

# Okta LDAP interface, for group-based scoping in Jamf Pro.
#
# Ported from jamfpro_ldap_server in msp-services-onboarding-tf. Attribute names moved
# under connection_settings / mappings_for_users and lost their map_ prefixes; see
# README.md for the full rename table and the one judgement call in it.
resource "jamfplatform_pro_ldap_server" "okta" {
  connection_settings = {
    display_name      = "Okta"
    directory_service = "Custom"
    hostname          = local.okta_ldap_hostname
    port              = 636
    use_ssl           = true

    authentication_type = "simple"
    connection_timeout  = 15
    search_timeout      = 60
    use_wildcards       = true

    account = {
      distinguished_username = "uid=${var.okta_service_account_username},${local.okta_base_dn}"
      password               = var.okta_ldap_password
    }
  }

  mappings_for_users = {
    user_mappings = {
      object_class_limitation = "all"
      object_classes          = "inetOrgPerson"
      search_base             = "ou=users,${local.okta_base_dn}"
      search_scope            = "All Subtrees"

      user_id       = "uid"
      username      = local.okta_use_shortname ? var.idp_shortname : "uid"
      real_name     = "cn"
      email_address = "mail"
      department    = "department"
      position      = "title"
      user_uuid     = "uid"
    }

    user_group_mappings = {
      object_class_limitation = "all"
      object_classes          = "groupofUniqueNames"
      search_base             = "ou=groups,${local.okta_base_dn}"
      search_scope            = "All Subtrees"

      group_id   = "uniqueIdentifier"
      group_name = "cn"
      group_uuid = "objectGUID"
    }

    user_group_membership_mappings = {
      membership_location = "group object"

      # "uniqueMember" is a groupOfUniqueNames attribute, so in group-object mode it
      # belongs in member_user_mapping, not group_membership_mapping. See README.md.
      member_user_mapping = "uniqueMember"

      use_dn                              = false
      recursive_lookups                   = false
      use_ldap_compare                    = false
      membership_calculation_optimization = true
    }
  }
}

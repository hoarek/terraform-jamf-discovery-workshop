###############################################################################
# Jamf Platform API — provider credentials
#
# Collected on wizard page 1. jamfplatform_base_url arrives as a full gateway URL;
# the onboarder expands the region radio (us / eu / apac) before writing tfvars, so
# Terraform never sees the short code.
#
# At the Platform API GA the gateway host moved from {region}.apigw.jamf.com to
# {region}.api.jamfcloud.com, beta credentials were revoked, and scope moved from
# tenant_id to environment_id. See README.md, Platform API GA.
###############################################################################

variable "jamfplatform_base_url" {
  description = "Regional Jamf Platform API gateway URL, e.g. https://us.api.jamfcloud.com. This is the API gateway, not the Jamf Pro console URL. Host only — the gateway serves every namespace at the root, so a trailing /api returns a bare 404."
  type        = string

  # Three separate failures, each with its own message, because they have different
  # causes and different fixes. A bare region code means the onboarder's expansion
  # did not run; the beta host means the tfvars predate GA; a path means someone
  # carried the beta's /api segment across.
  validation {
    condition     = can(regex("^https://", var.jamfplatform_base_url))
    error_message = "jamfplatform_base_url must be a full https URL such as https://us.api.jamfcloud.com. The onboarder expands the us/eu/apac region code before writing tfvars; a bare region code here means that expansion did not run."
  }

  validation {
    condition     = !can(regex("apigw\\.jamf\\.com", var.jamfplatform_base_url))
    error_message = "jamfplatform_base_url names the retired public-beta gateway. The Platform API GA host is https://{region}.api.jamfcloud.com — us, eu or apac. The beta host was retired at GA and provider 0.29.0-rc.4 and later cannot reach it."
  }

  validation {
    condition     = can(regex("^https://[^/]+/?$", var.jamfplatform_base_url))
    error_message = "jamfplatform_base_url must carry no path. The gateway serves the token endpoint and every API namespace at its root, so the /api segment used during the public beta is gone; a request carrying it gets the gateway's bare 404 page not found rather than a JSON error."
  }
}

variable "jamfplatform_client_id" {
  description = "OAuth2 client ID for the account.jamf.com Platform API integration. Public-beta credentials were revoked at GA and cannot be migrated; register a replacement integration in Jamf Account."
  type        = string
}

variable "jamfplatform_client_secret" {
  description = "OAuth2 client secret for the account.jamf.com Platform API integration."
  type        = string
  sensitive   = true
}

variable "jamfplatform_environment_id" {
  description = "Platform environment ID from the Integration details panel in account.jamf.com. Preferred over jamfplatform_tenant_id: one environment-scoped integration covers every tenant in the group, and it is the only scope that can hold the blueprint and compliance-benchmark permissions. Mutually exclusive with jamfplatform_tenant_id."
  type        = string
  default     = ""

  # Cross-variable validation, so this one variable carries the whole rule rather
  # than stating half of it here and half on jamfplatform_tenant_id. Both empty is
  # rejected too: that would leave the provider organization-scoped, which reaches
  # only the jamfplatform_account_* family and none of the modules in this repo, and
  # every apply would fail at configure time with a diagnostic about a construct the
  # operator never asked for.
  validation {
    condition     = !(var.jamfplatform_environment_id != "" && var.jamfplatform_tenant_id != "")
    error_message = "Set jamfplatform_environment_id or jamfplatform_tenant_id, not both. An API integration targets one scope or the other, and the provider rejects both together at configure time with Conflicting API Integration Scope."
  }

  validation {
    condition     = var.jamfplatform_environment_id != "" || var.jamfplatform_tenant_id != ""
    error_message = "Set jamfplatform_environment_id (preferred) or jamfplatform_tenant_id. With neither, the provider is organization-scoped, which reaches only the jamfplatform_account_* resources — none of which this repo deploys."
  }
}

variable "jamfplatform_tenant_id" {
  description = "Legacy tenant UUID from the Integration details panel in account.jamf.com. Prefer jamfplatform_environment_id; tenant scope costs one integration per tenant per product. Mutually exclusive with jamfplatform_environment_id, and supplying the identifier that does not match how the integration was registered is refused with 403 OWNERSHIP_FORBIDDEN even when both belong to the same customer."
  type        = string
  default     = ""
}

variable "min_request_interval_ms" {
  description = "Minimum interval between Jamf Platform API requests, in milliseconds. Workshop runs against a shared demo tenant should keep this at 100 and also set TF_CLI_ARGS_apply=\"-parallelism=1\"; see README.md."
  type        = number
  default     = 100

  validation {
    condition     = var.min_request_interval_ms >= 0
    error_message = "min_request_interval_ms must be zero or greater."
  }
}

###############################################################################
# Jamf Pro console URL
###############################################################################

variable "jamfpro_instance_url" {
  description = "Full URL of the Jamf Pro console, e.g. https://acme.jamfcloud.com. Leave empty: the root reads it from data.jamfplatform_pro_jamf_pro_server_url and passes it down. Kept as an override so this repo stays mergeable with the upstream public repo, which takes it as an input."
  type        = string
  default     = ""
}

###############################################################################
# Jamf Protect
###############################################################################

variable "jamfprotect_url" {
  description = "Jamf Protect tenant URL, e.g. https://acme.protect.jamfcloud.com."
  type        = string
  default     = ""
}

variable "jamfprotect_client_id" {
  description = "Jamf Protect API client ID."
  type        = string
  default     = ""
}

variable "jamfprotect_client_password" {
  description = "Jamf Protect API client password."
  type        = string
  sensitive   = true
  default     = ""
}

###############################################################################
# Jamf Security Cloud
#
# No credentials. Jamf Security Cloud is reached through the same Platform API
# gateway and the same integration as everything else in this repo, as the
# jamfplatform_security_cloud_* family, so the four jsc_* variables that used to
# configure the separate Jamf-Concepts/jsctfprovider provider are gone. A tenant
# that does not hold a Security Cloud capability is refused with 403 NOT_ENTITLED,
# which is an entitlement gap rather than anything these variables could fix.
#
# The two knobs below are the only Security Cloud inputs left. Neither is collected
# by configs/discovery-workshop.json; both default to the workshop's intent.
###############################################################################

variable "jsc_sync_refresh_interval_minutes" {
  description = "How often UEM Connect syncs device inventory and group membership from Jamf Pro, in minutes. Jamf Security Cloud accepts only the intervals its own admin UI offers."
  type        = number
  default     = 720

  validation {
    condition     = contains([60, 120, 240, 480, 720, 1440], var.jsc_sync_refresh_interval_minutes)
    error_message = "jsc_sync_refresh_interval_minutes must be one of 60, 120, 240, 480, 720 or 1440. The provider rejects anything else at plan time rather than letting the apply fail with an unattributed 422."
  }
}

variable "jsc_device_risk_uem_signaling_enabled" {
  description = "Send each device's risk level from Jamf Security Cloud back to Jamf Pro, so Jamf Pro can act on it. This is the capability the old 'JSC API Role Signalling' API role existed to grant; at GA it is a permission on the Platform API integration instead."
  type        = bool
  default     = true
}

###############################################################################
# Apple service tokens
#
# Both arrive base64-encoded by the onboarder's file upload handler. The encodings
# are not symmetric — see modules/configuration-apple-service-tokens/README.md.
###############################################################################

variable "device_enrollment_token_content" {
  description = "Base64 of the Automated Device Enrollment token (.p7m) downloaded from Apple Business Manager or Apple School Manager. Empty skips Automated Device Enrollment entirely."
  type        = string
  sensitive   = true
  default     = ""
}

variable "volume_purchasing_service_token_content" {
  description = "Base64 of the Volume Purchasing content token (.vpptoken) downloaded from Apple Business Manager or Apple School Manager. Empty skips volume purchasing entirely."
  type        = string
  sensitive   = true
  default     = ""
}

variable "device_enrollment_token_wo_version" {
  description = "Rotation counter for the Automated Device Enrollment token. Jamf Pro never returns the stored token, so Terraform cannot detect that the content changed. Bump this to force a re-upload."
  type        = number
  default     = 1
}

variable "volume_purchasing_service_token_wo_version" {
  description = "Rotation counter for the Volume Purchasing service token. Bump to force a re-upload."
  type        = number
  default     = 1
}

###############################################################################
# Identity provider selection
#
# One string, four values, exactly one writer of the jamfplatform_pro_sso_settings
# singleton per branch. See main.tf for the derivation and README.md for why this
# is a single string rather than three include_idp_* booleans.
###############################################################################

variable "idp_choice" {
  description = "Identity provider to integrate: okta, microsoft, google or none. 'none' still enables Jamf Account admin SSO, which wizard page 2 promises."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["okta", "microsoft", "none"], var.idp_choice)
    error_message = "idp_choice must be one of okta, microsoft or none. 'google' is accepted by the wizard but modules/identity-jamf-pro-google does not exist yet, so it fails here rather than silently deploying no SSO configuration at all."
  }
}

variable "idp_shortname" {
  description = "Short-name claim to match users on instead of NameID or email. Deliberately unvalidated at root: Okta accepts only mailNickName, Entra also accepts onPremisesSamAccountName, and each module validates its own set."
  type        = string
  default     = ""
}

###############################################################################
# Okta
###############################################################################

variable "okta_sso_metadata_url" {
  description = "Okta SAML app metadata URL. The Okta tenant host, LDAP hostname and directory base DN are all derived from it."
  type        = string
  default     = ""
}

variable "okta_service_account_username" {
  description = "Okta read-only administrator username used to bind to the Okta LDAP interface."
  type        = string
  default     = ""
}

variable "okta_ldap_password" {
  description = "Password for the Okta LDAP service account."
  type        = string
  sensitive   = true
  default     = ""
}

variable "okta_ios_secret_key" {
  description = "Okta iOS Verify secret key. Collected by the wizard; no module in this repo consumes it. See README.md, Open items."
  type        = string
  sensitive   = true
  default     = ""
}

variable "okta_oidcclientid" {
  description = "Okta OIDC client ID for Jamf Connect. Collected by the wizard; no module in this repo consumes it. Distinct from okta_client_id, which is a Jamf Trust setting."
  type        = string
  default     = ""
}

###############################################################################
# Okta — device-side payload inputs
#
# Consumed by modules/management-okta-psso, which templates three configuration
# profiles from them. configs/discovery-workshop.json does not collect any of
# these, so include_okta_psso defaults to false.
###############################################################################

variable "okta_short_url" {
  description = "Okta short URL, e.g. acme.okta.com. Consumed by management-okta-psso."
  type        = string
  sensitive   = true
  default     = ""
}

variable "okta_org_name" {
  description = "Okta org name used in the Okta Verify configuration profile. Consumed by management-okta-psso."
  type        = string
  sensitive   = true
  default     = ""
}

variable "okta_scep_url" {
  description = "Okta Device Access SCEP URL. Consumed by management-okta-psso."
  type        = string
  sensitive   = true
  default     = ""
}

variable "okta_psso_client" {
  description = "Okta Platform SSO client ID. Consumed by management-okta-psso."
  type        = string
  sensitive   = true
  default     = ""
}

variable "okta_scep_username" {
  description = "Okta SCEP username. Consumed by management-okta-psso."
  type        = string
  sensitive   = true
  default     = ""
}

variable "okta_scep_password" {
  description = "Okta SCEP challenge password. Consumed by management-okta-psso."
  type        = string
  sensitive   = true
  default     = ""
}

###############################################################################
# Microsoft Entra ID
###############################################################################

variable "entra_sso_metadata_url" {
  description = "Entra ID federation metadata URL for the Jamf Pro enterprise application. The tenant ID is derived from its fourth path segment."
  type        = string
  default     = ""
}

variable "entra_configure_cloud_identity_provider" {
  description = "Register the Entra ID Cloud Identity Provider connection for group lookups. A global administrator must still grant consent in the Jamf Pro console after the first apply."
  type        = bool
  default     = true
}

variable "entra_enable_advanced_settings" {
  description = "Wizard-only field. It controls whether the advanced Entra fields are shown on the form; no Terraform resource consumes it. Declared so every key in the config resolves to a real variable."
  type        = bool
  default     = false
}

variable "entra_oidcclientid" {
  description = "Entra OIDC client ID for Jamf Connect. Collected by the wizard; no module in this repo consumes it. See README.md, Open items."
  type        = string
  default     = ""
}

variable "entra_oidcscopes" {
  description = "Entra OIDC scope application ID URI for Jamf Connect. Collected by the wizard; unconsumed."
  type        = string
  default     = ""
}

variable "entra_oidcropgid" {
  description = "Entra OIDC ROPG client ID for Jamf Connect network authentication. Collected by the wizard; unconsumed."
  type        = string
  default     = ""
}

variable "entra_ropgtenant" {
  description = "Entra tenant used for the Jamf Connect ROPG flow. Collected by the wizard; unconsumed. MSP falls back to the tenant ID derived from the metadata URL."
  type        = string
  default     = ""
}

###############################################################################
# Google Workspace
#
# Declared so every key in configs/discovery-workshop.json resolves to a real root
# variable. modules/identity-jamf-pro-google does not exist yet and idp_choice
# rejects "google"; see README.md, Open items.
###############################################################################

variable "google_domain" {
  description = "Google Workspace primary domain, e.g. acme.com."
  type        = string
  default     = ""
}

variable "google_sso_metadata_file_content" {
  description = "Base64 of the Google SAML metadata XML. jamfplatform_pro_sso_settings takes this directly as saml_settings.federation_metadata_file, so no conversion is needed for the SAML half."
  type        = string
  sensitive   = true
  default     = ""
}

variable "google_ldap_keystore_file_content" {
  description = "Base64 of the Google Secure LDAP client certificate archive (.zip). The provider needs a base64 PKCS#12 (.p12) plus a password, and Google issues a zip of .crt and .key. Converting one to the other is not a Terraform operation; see README.md, Open items."
  type        = string
  sensitive   = true
  default     = ""
}

variable "google_oidcclientid" {
  description = "Google OIDC client ID for Jamf Connect. Collected by the wizard; unconsumed."
  type        = string
  default     = ""
}

variable "google_oidcclientsecret" {
  description = "Google OIDC client secret for Jamf Connect. Collected by the wizard; unconsumed."
  type        = string
  sensitive   = true
  default     = ""
}

###############################################################################
# Jamf Connect
###############################################################################

variable "include_jamf_connect" {
  description = "Deploy Jamf Connect. Collected by the wizard on all three IdP pages; no module in this repo deploys Jamf Connect yet, so setting it has no effect. See README.md, Open items."
  type        = bool
  default     = false
}

variable "jamf_connect_license_content" {
  description = "Base64 of the Jamf Connect license file. Collected by the wizard; unconsumed."
  type        = string
  sensitive   = true
  default     = ""
}

###############################################################################
# Feature flags
#
# The six in configs/discovery-workshop.json forced_modules default to false here
# and are set true by the generated tfvars. The remainder default to false and are
# not set by that config at all.
###############################################################################

variable "include_onboarder_management_macOS" {
  description = "Deploy the macOS management foundation: categories, computer management settings, smart groups and Rosetta."
  type        = bool
  default     = false
}

variable "include_onboarder_management_mobile" {
  description = "Deploy the mobile management foundation: iOS configuration profiles."
  type        = bool
  default     = false
}

variable "include_filevault" {
  description = "Deploy FileVault disk encryption configuration and escrow."
  type        = bool
  default     = false
}

variable "include_jsc_uemc" {
  description = "Register Jamf Pro as the Jamf Security Cloud UEM connector. Jamf Security Cloud provisions and manages its own credentials on the tenant, so no API role or client is created here — those resources were removed from the provider at the Platform API GA. Also required by include_jsc_all_services to push activation profiles into Jamf Pro."
  type        = bool
  default     = false
}

variable "include_jsc_all_services" {
  description = "Create the Jamf Security Cloud activation profile covering Network Security and Content Controls, and deploy its configuration profiles into Jamf Pro. Deployment needs UEM Connect, so with include_jsc_uemc false the module mints the profile and surfaces the activation code instead."
  type        = bool
  default     = false
}

variable "include_jamf_protect_trial_kickstart" {
  description = "Connect Jamf Protect to Jamf Pro and deploy the Jamf Protect plan."
  type        = bool
  default     = false
}

###############################################################################
# Feature flags — device-side identity payloads
#
# All three default false. configs/discovery-workshop.json does not set them, and
# two of the three cannot be safely enabled as vendored; see README.md.
###############################################################################

variable "include_jamf_pro_admin_sso" {
  description = "Force the OIDC-only Jamf Account admin SSO module on. Normally left false: the root enables it automatically when idp_choice is 'none', because it writes the same jamfplatform_pro_sso_settings singleton as the identity modules."
  type        = bool
  default     = false
}

variable "include_ssoe_okta" {
  description = "Deploy the macOS Okta SSO extension profile, script and policy. DO NOT enable as vendored: the bundled .mobileconfig has a Jamf demo Okta tenant and SCEP URL hardcoded in it. See README.md, Open items."
  type        = bool
  default     = false
}

variable "include_okta_psso" {
  description = "Deploy Okta Platform SSO: SCEP profile, Okta Verify package and policy, and two PSSO profiles. Requires the six okta_scep / okta_psso / okta_org_name / okta_short_url inputs, which the Discovery Workshop config does not collect."
  type        = bool
  default     = false
}

variable "include_microsoft_psso" {
  description = "Deploy Microsoft Platform SSO: Company Portal package and policy, and the Entra PSSO profile. Needs no additional inputs; the bundled profile is tenant-agnostic."
  type        = bool
  default     = false
}

variable "device_enrollment_token_content_filename" {
  description = "Original filename of the uploaded ADE token, recorded by the onboarder for reference. Not consumed by Terraform."
  type        = string
  default     = ""
}

variable "volume_purchasing_service_token_content_filename" {
  description = "Original filename of the uploaded VPP token, recorded by the onboarder for reference. Not consumed by Terraform."
  type        = string
  default     = ""
}

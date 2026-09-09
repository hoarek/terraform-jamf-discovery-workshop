###############################################################################
# Outputs
#
# The workflow writes these to artifacts and the onboarder polls for them. Any
# artifact whose filename contains "credential" is treated as a credential bundle
# and surfaced on the completion page; the rest are shown as plain output.
###############################################################################

# The operator needs this before Apple will issue an Automated Device Enrollment
# token, so it is available on the first run — the run with no token yet. Wizard
# page 1 says "using the Public Key supplied earlier", which this satisfies only on
# a second pass; see README.md, Open items.
output "automated_device_enrollment_public_key" {
  description = "Jamf Pro's Automated Device Enrollment public key. Upload this to Apple Business Manager or Apple School Manager under Device Management Services to obtain the .p7m server token."
  value       = module.configuration-apple-service-tokens.automated_device_enrollment_public_key
}

output "automated_device_enrollment_token_expiration_date" {
  description = "Expiry of the uploaded Automated Device Enrollment token, or null when no token was supplied. Apple issues these for one year."
  value       = module.configuration-apple-service-tokens.automated_device_enrollment_token_expiration_date
}

output "volume_purchasing_token_expiration" {
  description = "Expiry of the uploaded Volume Purchasing service token, or null when no token was supplied."
  value       = module.configuration-apple-service-tokens.volume_purchasing_token_expiration
}

# Treat as a credential: this URL bypasses SSO. It is the way back into the console
# if the IdP integration misbehaves, so a workshop should capture it before anyone
# signs out. Null when idp_choice is 'none', because the OIDC-only admin SSO module
# does not manage the failover URL.
output "sso_failover_url_credential" {
  description = "Jamf Pro SSO failover URL. Bypasses SSO — treat as a credential and store it before signing out of the console."
  # At most one identity module has count = 1, so concat yields a list of zero or
  # one element and one() collapses it to the value or null.
  value = one(concat(
    module.identity-jamf-pro-okta[*].sso_failover_url,
    module.identity-jamf-pro-microsoft-entra[*].sso_failover_url,
  ))
  sensitive = true
}

output "saml_entity_id" {
  description = "SAML EntityID configured in Jamf Pro. Must match the Audience/Identifier configured on the IdP application. Null when idp_choice is 'none'."
  value = one(concat(
    module.identity-jamf-pro-okta[*].saml_entity_id,
    module.identity-jamf-pro-microsoft-entra[*].saml_entity_id,
  ))
}

output "okta_tenant" {
  description = "Okta tenant host derived from the SAML metadata URL. Null unless idp_choice is 'okta'."
  value       = one(module.identity-jamf-pro-okta[*].okta_tenant)
}

output "okta_ldap_server_id" {
  description = "Jamf Pro ID of the Okta LDAP server connection. Null unless idp_choice is 'okta'."
  value       = one(module.identity-jamf-pro-okta[*].ldap_server_id)
}

output "entra_tenant_id" {
  description = "Entra tenant (directory) ID derived from the federation metadata URL. The global administrator needs it for the Cloud Identity Provider consent step. Null unless idp_choice is 'microsoft'."
  value       = one(module.identity-jamf-pro-microsoft-entra[*].entra_tenant_id)
}

output "entra_cloud_identity_provider_id" {
  description = "Jamf Pro ID of the Entra ID Cloud Identity Provider connection. Null unless idp_choice is 'microsoft' and entra_configure_cloud_identity_provider is true."
  value       = one(module.identity-jamf-pro-microsoft-entra[*].cloud_identity_provider_id)
}

output "jamfpro_instance_url" {
  description = "Jamf Pro console URL, read from the tenant unless overridden by var.jamfpro_instance_url."
  value       = local.jamfpro_instance_url
}

###############################################################################
# Jamf Security Cloud
###############################################################################

output "jsc_uem_connect_id" {
  description = "Integration ID of the Jamf Security Cloud UEM Connect connector. Null unless include_jsc_uemc is true. Needed to import the connector into another workspace — a tenant holds exactly one and a second create is refused."
  value       = one(module.configuration-jamf-security-cloud-jamf-pro[*].uem_connect_id)
}

# Treat as a credential: the activation code on its own is enough to enrol a device.
# It is the fallback distribution route when UEM Connect is not deployed and Jamf
# Security Cloud therefore pushed no configuration profile into Jamf Pro.
output "jsc_activation_code_credential" {
  description = "Jamf Security Cloud activation code end users enrol Jamf Trust against. Null unless include_jsc_all_services is true. Distribute as an enrollment link where include_jsc_uemc is false."
  value       = one(module.configuration-jamf-security-cloud-all-services[*].activation_code)
  sensitive   = true
}

# The activation profile's configuration profiles are scoped to two smart groups that
# each carry a dummy serial-number criterion, so a workshop apply reaches no real
# devices. Jamf Security Cloud writes those profiles' descriptions, not Terraform, so
# this output is where the follow-up step is stated.
output "jsc_scope_groups_pending_criteria_removal" {
  description = "Smart groups scoped to the deployed Jamf Security Cloud configuration profiles, each with the dummy criterion to remove in Jamf Pro to turn the deployment on. Null unless include_jsc_all_services is true. JSON-encoded so the workflow can collect it with tofu output -raw."
  value       = jsonencode(one(module.configuration-jamf-security-cloud-all-services[*].scope_groups_pending_criteria_removal))
}

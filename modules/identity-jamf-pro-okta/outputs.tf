output "sso_failover_url" {
  description = "Jamf Pro SSO failover URL. Treat as a credential: it bypasses SSO. Capture it before signing out of the console."
  value       = jamfplatform_pro_sso_failover_url.okta.failover_url
  sensitive   = true
}

output "ldap_server_id" {
  description = "Jamf Pro ID of the Okta LDAP server connection."
  value       = jamfplatform_pro_ldap_server.okta.id
}

output "okta_tenant" {
  description = "Okta tenant host derived from the SAML metadata URL, e.g. acme.okta.com."
  value       = local.okta_tenant
}

output "saml_entity_id" {
  description = "SAML EntityID configured in Jamf Pro. Must match the Audience/Identifier in the Okta SAML app."
  value       = jamfplatform_pro_sso_settings.okta.saml_settings.entity_id
}

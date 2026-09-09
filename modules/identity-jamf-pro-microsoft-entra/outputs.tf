output "sso_failover_url" {
  description = "Jamf Pro SSO failover URL. Treat as a credential: it bypasses SSO. Capture it before signing out of the console."
  value       = jamfplatform_pro_sso_failover_url.entra.failover_url
  sensitive   = true
}

output "entra_tenant_id" {
  description = "Entra tenant (directory) ID derived from the federation metadata URL. Needed for the manual consent step."
  value       = local.entra_tenant_id
}

output "cloud_identity_provider_id" {
  description = "Jamf Pro ID of the Entra ID Cloud Identity Provider connection, or null when entra_configure_cloud_identity_provider is false."
  value       = one(jamfplatform_pro_cloud_identity_provider.entra[*].id)
}

output "saml_entity_id" {
  description = "SAML EntityID configured in Jamf Pro. Must match the Identifier (Entity ID) on the Entra enterprise application."
  value       = jamfplatform_pro_sso_settings.entra.saml_settings.entity_id
}

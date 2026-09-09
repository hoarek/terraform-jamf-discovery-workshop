###############################################################################
# Outputs
#
# jp_client_id and jp_client_secret are gone with the jamfplatform_pro_api_client
# that produced them. Nothing consumed them at the root, and there is no equivalent
# to publish: under platform_tenant the credentials belong to Jamf Security Cloud
# and are never returned.
###############################################################################

output "uem_connect_id" {
  description = "Integration ID Jamf Security Cloud assigned to the UEM Connect connector. Needed to import the connector into another workspace, or to run the synchronize action against it."
  value       = jamfplatform_security_cloud_uem_connect.jamf_pro.id
}

output "jamf_pro_tenant_id" {
  description = "Jamf Pro tenant identifier the connector syncs with, resolved from the provider's configured scope."
  value       = data.jamfplatform_pro_tenant_id.jamf_pro.tenant_id
}

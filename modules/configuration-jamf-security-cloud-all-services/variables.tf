###############################################################################
# Inputs
#
# Nine of the previous eleven variables are gone. jsc_username, jsc_password,
# jamfplatform_base_url, jamfplatform_client_id, jamfplatform_client_secret,
# clientid and clientsecret were all either unreferenced or configured the retired
# jsc provider. okta_client_id and okta_org_domain were read only by the commented-
# out jsc_oktaidp block, and an activation profile's identity provider is not
# something the native resource can select. block_page_logo, enable_jsc_uemc,
# enable_jsc_uemc_output, category_id_output, jsc_mobile_plist,
# supervisedplist_output and random_string were never referenced either.
###############################################################################

variable "deploy_to_jamf_pro" {
  description = "Whether to push the activation profile's configuration profiles into Jamf Pro. Requires a UEM Connect connector that is connected to Jamf Pro, so the root passes include_jsc_uemc. False still creates the activation profile and publishes its code as an output; nothing is pushed. This is deliberately a separate input from uem_connect_id rather than derived from it, because it drives a count and so has to be known at plan time."
  type        = bool
  default     = false
}

variable "uem_connect_id" {
  description = "Integration ID of the Jamf Security Cloud UEM Connect connector, from module.configuration-jamf-security-cloud-jamf-pro. Referenced only to order the deployment behind the connector's creation — nothing here reads the value. Unknown at plan time on a first apply, which is why it cannot also serve as the deploy_to_jamf_pro gate."
  type        = string
  default     = ""
}

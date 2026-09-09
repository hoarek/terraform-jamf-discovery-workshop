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


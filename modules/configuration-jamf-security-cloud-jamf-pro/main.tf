## Call Terraform provider
#
# 1.11 rather than the root's 1.14: nothing here uses an action block. The 1.14 floor
# belongs to configuration-jamf-security-cloud-all-services, which deploys through a
# lifecycle { action_trigger }.
terraform {
  required_version = ">= 1.11"
  required_providers {
    jamfplatform = {
      source                = "Jamf-Concepts/jamfplatform"
      version               = "~> 0.29"
      configuration_aliases = [jamfplatform.jpro]
    }
  }
}

###############################################################################
# UEM Connect
#
# Before the Platform API GA this module built the integration by hand: three
# jamfplatform_pro_api_role resources, a jamfplatform_pro_api_client holding them,
# and a jsc_uemc from the separate Jamf-Concepts/jsctfprovider provider consuming
# that client's ID and secret. All four constructs are gone.
#
# The API role and client endpoints were unpublished at GA to close a privilege-
# escalation path — an integration could mint a client holding privileges it did not
# itself hold — so the provider no longer implements either resource type. There is
# no replacement in Terraform: the equivalent is the Platform API integrations UI in
# Jamf Account. That removes the whole reason the old shape existed, because the
# native jamfplatform_security_cloud_uem_connect resource needs no Jamf Pro
# credentials at all.
#
# platform_tenant is why. Jamf Security Cloud provisions and manages its own
# credentials on the named tenant, so nothing here handles a secret and neither the
# configuration nor the state holds one. The three roles the old module wrote —
# device sync, risk signalling, activation profile deployment — are covered by the
# 31-privilege "JSC Connector" role Jamf Security Cloud creates for itself.
###############################################################################

# The Jamf Pro tenant identifier is the one value that cannot be read off the UEM
# Connect screen. This resolves it from whatever scope the provider is configured
# with — under a platform environment, the Jamf Pro tenant in that environment — so
# it never has to be carried between consoles by hand. This data source exists
# because of this exact resource.
data "jamfplatform_pro_tenant_id" "jamf_pro" {
  provider = jamfplatform.jpro
}

resource "jamfplatform_security_cloud_uem_connect" "jamf_pro" {
  provider = jamfplatform.jpro

  uem_vendor = "JAMF_PRO"
  enabled    = true

  platform_tenant = {
    tenant_id = data.jamfplatform_pro_tenant_id.jamf_pro.tenant_id
  }

  scheduled_sync_enabled            = true
  sync_refresh_interval_minutes     = var.sync_refresh_interval_minutes
  device_risk_uem_signaling_enabled = var.device_risk_uem_signaling_enabled

  # Devices Jamf Pro no longer reports as managed are dropped from Jamf Security
  # Cloud. A workshop tenant churns through test devices, and leaving them behind
  # makes every subsequent device count meaningless.
  uem_auto_delete_behavior = "remove_deleted_or_unmanaged"

  # Stop retrying once the credentials stop working, rather than logging a failing
  # sync on the interval indefinitely.
  disable_sync_on_auth_error = true

  # user_data_field_mapping is deliberately omitted: omitting the whole block takes
  # Jamf Security Cloud's defaults, which is what the admin UI's "Use default data
  # field mapping" checkbox selects. Declaring the block and leaving fields out
  # would instead replace what it does not mention.
  #
  # group_membership_mapping is omitted for the same structural reason. This repo
  # creates no Security Cloud device groups to map Jamf Pro groups onto, and a
  # declared-but-empty block clears every mapping on the tenant — including any a
  # PSE set up in the console before the workshop.

  # A tenant holds exactly one UEM Connect integration and a second create is
  # refused, so a tenant that already has one needs an import rather than an apply.
  # See README.md.
}

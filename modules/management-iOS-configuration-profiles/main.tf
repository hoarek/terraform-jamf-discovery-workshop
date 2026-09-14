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

# All restriction profiles, kiosk/shared-mode profiles, both Demo/Restrictions
# categories, the Device Type extension attribute, and the Kiosk/Shared Device
# smart groups were removed in the Fred review pass (2026-09-07). The module
# directory is kept so the support_files/ payloads stay in the repo for reference
# and the git history stays clean, but nothing here creates any Jamf Pro object.

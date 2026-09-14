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

# management-iOS-configuration-profiles was removed in the Fred review pass
# (2026-09-07). Its restriction and kiosk/shared-mode profiles are gone; the
# only iOS profiles in the workshop flow are those deployed by Jamf Security
# Cloud via the activation profile. This module is kept and gated by
# include_onboarder_management_mobile so the toggle remains meaningful when
# mobile content is added back.

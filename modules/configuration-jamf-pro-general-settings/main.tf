## Call Terraform provider
terraform {
  required_providers {
    jamfplatform = {
      source                = "Jamf-Concepts/jamfplatform"
      version               = "~> 0.29"
      configuration_aliases = [jamfplatform.jpro]
    }
  }
}

###############################################################################
# User-Initiated Enrollment (UIE)
###############################################################################

resource "jamfplatform_pro_user_initiated_enrollment_settings" "uie" {
  provider = jamfplatform.jpro

  enable_computer_enrollment    = true
  create_management_account     = true
  management_username           = "lapsadmin"
  hide_management_account       = true
  launch_self_service           = false
  sign_quickadd_package         = false
  skip_certificate_installation = false
}

###############################################################################
# Re-Enrollment
###############################################################################

resource "jamfplatform_pro_re_enrollment_settings" "re_enroll" {
  provider = jamfplatform.jpro

  clear_management_history           = "DELETE_EVERYTHING"
  clear_extension_attributes         = true
  clear_location_information         = true
  clear_location_information_history = false
  clear_policy_logs                  = true
  clear_software_update_plans        = true
}

###############################################################################
# Self Service
###############################################################################

resource "jamfplatform_pro_self_service_plus_settings" "self_service_plus" {
  provider = jamfplatform.jpro

  enabled = true
}

# APNs push certificate is customer pre-work — no Apple API exists to automate
# it. notifications_enabled = true activates the setting; the notifications
# will not fire until the push cert is uploaded in Settings → Global →
# Push Certificates in Jamf Pro.
resource "jamfplatform_pro_self_service_macos_settings" "self_service_macos" {
  provider = jamfplatform.jpro

  install_automatically = false
  notifications_enabled = true
}

###############################################################################
# Distribution point
#
# Commented out: Jamf Cloud tenants already have a JCDS configured by Jamf and
# the API rejects a second one with "JAMF_CLOUD is already configured". The
# existing JCDS cannot be deleted from this tenant, so Terraform skips it.
###############################################################################

# resource "jamfplatform_pro_cloud_distribution_point" "jcds" {
#   provider = jamfplatform.jpro
#
#   cdn_type = "JAMF_CLOUD"
#   master   = true
# }

###############################################################################
# LAPS
###############################################################################

resource "jamfplatform_pro_local_admin_password_settings" "laps" {
  provider = jamfplatform.jpro

  laps_for_prestage_accounts_enabled = false
  rotation_interval                  = "7 days"
  rotation_after_viewing_interval    = "1 hour"
}

###############################################################################
# App Installer
###############################################################################

resource "jamfplatform_pro_app_installer_settings" "app_installer" {
  provider = jamfplatform.jpro

  deployment_settings = {
    batch_size = 1000
  }
}

###############################################################################
# Managed software updates
###############################################################################

resource "jamfplatform_pro_managed_software_update" "msu" {
  provider = jamfplatform.jpro

  enabled = true
}

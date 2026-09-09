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

# The ADE public key is a chicken-and-egg dependency: Apple Business/School Manager
# will not issue a server token until it has been given Jamf Pro's public key. Reading
# it here lets the root module surface it as an output, which the workflow publishes as
# a build artifact for the wizard to collect. This replaces the MSP approach of writing
# PublicKey.pem to disk with local_file + a local-exec mkdir, which STYLE_GUIDE.md
# discourages ("Avoid changes that depend on local-only files").
data "jamfplatform_pro_automated_device_enrollment_public_key" "current" {}

# Automated Device Enrollment (ADE) instance.
#
# server_token takes the base64 of the raw .p7m bytes. The onboarder base64-encodes
# every uploaded file before it reaches tfvars, and the provider base64-decodes this
# attribute back to raw bytes before sending, so the wizard value is passed straight
# through with no transformation.
resource "jamfplatform_pro_automated_device_enrollment" "default" {
  count = var.device_enrollment_token_content != "" ? 1 : 0

  name                    = var.device_enrollment_display_name
  server_token            = var.device_enrollment_token_content
  server_token_wo_version = var.device_enrollment_token_wo_version
  token_file_name         = "discovery-workshop-ade-token.p7m"

  # Create blocks until Jamf Pro reports the initial Apple sync complete. The default
  # is 5 minutes; large estates and first-time syncs regularly exceed that.
  timeouts = {
    create = "15m"
    update = "15m"
  }
}

# Names the ADE server used for Managed Apple Account access management. Singleton, so
# it is created once and only when there is an ADE instance for it to point at.
resource "jamfplatform_pro_access_management_settings" "default" {
  count = var.device_enrollment_token_content != "" ? 1 : 0

  automated_device_enrollment_server_uuid = jamfplatform_pro_automated_device_enrollment.default[0].server_uuid
}

# Volume Purchasing (VPP) location.
#
# Encoding differs from ADE and the asymmetry is deliberate. A .vpptoken file is
# already base64 text on disk, and the provider documents that it must NOT be
# base64-encoded again. The onboarder encodes it anyway (it encodes all uploads
# unless the field sets skip_base64_encode), so the value arriving here is
# base64(base64) and needs exactly one decode. This matches what MSP does.
resource "jamfplatform_pro_volume_purchasing_location" "default" {
  count = var.volume_purchasing_service_token_content != "" ? 1 : 0

  name                     = var.volume_purchasing_display_name
  service_token            = base64decode(var.volume_purchasing_service_token_content)
  service_token_wo_version = var.volume_purchasing_service_token_wo_version

  automatically_populate_purchased_content  = true
  send_notification_when_no_longer_assigned = false
  auto_register_managed_users               = true

  timeouts = {
    create = "10m"
    update = "10m"
  }
}

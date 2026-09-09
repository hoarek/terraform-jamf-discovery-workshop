###############################################################################
# Inputs
#
# The provider credentials this module used to take are gone. It no longer builds
# anything in Jamf Pro itself, so it needs no Jamf Pro client ID or secret, no
# jamfpro_instance_url — platform_tenant resolves the address from the tenant — and
# no Jamf Security Cloud username or password, because Jamf Security Cloud is
# reached through the same Platform API integration as the rest of the repo.
###############################################################################

variable "sync_refresh_interval_minutes" {
  description = "How often UEM Connect syncs device inventory and group membership from Jamf Pro, in minutes. Jamf Security Cloud accepts only 60, 120, 240, 480, 720 or 1440."
  type        = number
  default     = 720
}

variable "device_risk_uem_signaling_enabled" {
  description = "Send each device's risk level from Jamf Security Cloud back to Jamf Pro."
  type        = bool
  default     = true
}

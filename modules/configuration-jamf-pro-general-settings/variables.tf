## Define variables

variable "jamfplatform_base_url" {
  description = "Jamf Pro instance URL."
  type        = string
}

variable "jamfplatform_client_id" {
  description = "Jamf Pro API client ID."
  type        = string
}

variable "jamfplatform_client_secret" {
  description = "Jamf Pro API client secret."
  type        = string
  sensitive   = true
}

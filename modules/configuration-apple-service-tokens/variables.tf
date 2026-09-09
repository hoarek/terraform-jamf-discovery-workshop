variable "device_enrollment_token_content" {
  description = "Base64-encoded contents of the Apple Business/School Manager Device Management Service token (.p7m). Empty string skips Automated Device Enrollment entirely."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.device_enrollment_token_content == "" || can(base64decode(var.device_enrollment_token_content))
    error_message = "device_enrollment_token_content must be empty or a valid base64-encoded string."
  }
}

variable "device_enrollment_token_wo_version" {
  description = "Rotation trigger for the write-only ADE server token. Bump to re-send the current token to Jamf Pro."
  type        = number
  default     = 1
}

variable "device_enrollment_display_name" {
  description = "Display name for the Automated Device Enrollment instance in Jamf Pro."
  type        = string
  default     = "Apple Business Manager"
}

variable "volume_purchasing_service_token_content" {
  description = "Base64-encoded contents of the Apple Business/School Manager Content Token (.vpptoken). The file is itself base64, so this value is doubly encoded. Empty string skips Volume Purchasing entirely."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.volume_purchasing_service_token_content == "" || can(base64decode(var.volume_purchasing_service_token_content))
    error_message = "volume_purchasing_service_token_content must be empty or a valid base64-encoded string."
  }
}

variable "volume_purchasing_service_token_wo_version" {
  description = "Rotation trigger for the write-only VPP service token. Bump to re-send the current token to Jamf Pro."
  type        = number
  default     = 1
}

variable "volume_purchasing_display_name" {
  description = "Display name for the Volume Purchasing location in Jamf Pro."
  type        = string
  default     = "Apple Business Manager"
}

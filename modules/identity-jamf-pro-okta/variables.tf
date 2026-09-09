variable "okta_sso_metadata_url" {
  description = "Okta SAML app metadata URL. The Okta tenant host, LDAP hostname and directory base DN are all derived from this, so it must be a real Okta URL."
  type        = string

  validation {
    condition     = can(regex("^(?:https?://)?[^/:]+\\.[^/:]+\\.[^/:]+", var.okta_sso_metadata_url))
    error_message = "okta_sso_metadata_url must contain a three-label host such as acme.okta.com; the Okta LDAP hostname and base DN are derived from it."
  }
}

variable "okta_service_account_username" {
  description = "Okta read-only administrator username used to bind to the Okta LDAP interface. The uid= component of the bind DN."
  type        = string
}

variable "okta_ldap_password" {
  description = "Password for the Okta LDAP service account."
  type        = string
  sensitive   = true
}

variable "idp_shortname" {
  description = "Short-name claim to map onto the Jamf Pro LDAP Username attribute. Empty string uses the default uid mapping and matches users on email. Only 'mailNickName' is supported for Okta, and it requires a matching custom attribute in Okta plus the Jamf Pro SAML app set to the Okta Username prefix format."
  type        = string
  default     = ""

  validation {
    condition     = var.idp_shortname == "" || contains(["mailNickName"], var.idp_shortname)
    error_message = "idp_shortname must be empty or 'mailNickName' when the identity provider is Okta."
  }
}

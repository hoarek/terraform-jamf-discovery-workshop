variable "entra_sso_metadata_url" {
  description = "Entra ID federation metadata URL for the Jamf Pro enterprise application. The tenant ID is derived from its fourth path segment, so it must be a real login.microsoftonline.com metadata URL."
  type        = string

  validation {
    condition     = length(split("/", var.entra_sso_metadata_url)) > 3 && split("/", var.entra_sso_metadata_url)[3] != ""
    error_message = "entra_sso_metadata_url must be a full federation metadata URL such as https://login.microsoftonline.com/<tenant-id>/federationmetadata/2007-06/federationmetadata.xml; the Entra tenant ID is derived from the fourth path segment."
  }
}

variable "idp_shortname" {
  description = "Short-name claim to match users on instead of NameID. Empty string matches on email. Setting it also flips the SAML user mapping to USERNAME, so the Entra enterprise application must emit a claim of this name."
  type        = string
  default     = ""

  validation {
    condition     = var.idp_shortname == "" || contains(["mailNickName", "onPremisesSamAccountName"], var.idp_shortname)
    error_message = "idp_shortname must be empty, 'mailNickName' or 'onPremisesSamAccountName' when the identity provider is Entra ID."
  }
}

variable "entra_configure_cloud_identity_provider" {
  description = "Register the Entra ID Cloud Identity Provider connection in Jamf Pro for group lookups. An Entra global administrator must still grant consent in the Jamf Pro console after the first apply. Set false to leave directory integration entirely manual, as msp-services-onboarding-tf does."
  type        = bool
  default     = true
}

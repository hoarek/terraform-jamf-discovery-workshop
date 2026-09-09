locals {
  # Jamf Pro's own URL, read from the tenant rather than collected from the wizard.
  # Trailing slash trimmed before it is concatenated into the SAML EntityID.
  jamf_pro_url = trimsuffix(data.jamfplatform_pro_jamf_pro_server_url.current.url, "/")

  # The Entra tenant ID is never collected by the wizard; it is the fourth path segment
  # of the federation metadata URL, which always looks like
  # https://login.microsoftonline.com/<tenant-id>/federationmetadata/2007-06/federationmetadata.xml
  # This is how msp-services-onboarding-tf derives it too. Not needed by the SSO
  # settings below, but exposed as an output because the operator needs it for the
  # manual Cloud Identity Provider step.
  entra_tenant_id = split("/", var.entra_sso_metadata_url)[3]

  # When a short-name claim is configured, Jamf Pro matches on a named SAML attribute
  # rather than NameID/email.
  entra_use_shortname = var.idp_shortname != ""
}

locals {
  # Jamf Pro's own URL, read from the tenant rather than collected from the wizard.
  # The trailing slash is trimmed because this value is concatenated into the SAML
  # EntityID below, and Jamf Pro treats "…com//saml/metadata" as a different entity.
  jamf_pro_url = trimsuffix(data.jamfplatform_pro_jamf_pro_server_url.current.url, "/")

  # Okta tenant host, derived from the SAML metadata URL the PSE pastes in.
  # e.g. "https://acme.okta.com/app/foo/sso/saml/metadata" -> "acme.okta.com"
  # Ported unchanged from msp-services-onboarding-tf so behaviour matches. Note the
  # capture group admits a :port, which would then leak into the split() results
  # below; Okta metadata URLs do not carry one in practice.
  okta_tenant    = one(regex("^(?:https?://)?([^/:]+(?::[0-9]+)?)", var.okta_sso_metadata_url)[*])
  okta_subdomain = split(".", local.okta_tenant)[0]
  okta_sld       = split(".", local.okta_tenant)[1]
  okta_tld       = split(".", local.okta_tenant)[2]

  # Okta's LDAP interface is always <subdomain>.ldap.<sld>.<tld>, and its directory
  # tree mirrors the tenant host as dc= components.
  okta_ldap_hostname = "${local.okta_subdomain}.ldap.${local.okta_sld}.${local.okta_tld}"
  okta_base_dn       = "dc=${local.okta_subdomain},dc=${local.okta_sld},dc=${local.okta_tld}"

  # When a short-name claim is configured, Jamf Pro matches on username rather than
  # email, and the LDAP username attribute must match the claim.
  okta_use_shortname = var.idp_shortname != ""
}

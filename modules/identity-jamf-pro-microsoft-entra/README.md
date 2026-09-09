# identity-jamf-pro-microsoft-entra

Configures Jamf Pro's **own** identity settings for Microsoft Entra ID. Ported from
`modules/Optional/IdentityProvider-Microsoft` in `jamf/msp-services-onboarding-tf`.

| Resource | Purpose |
| --- | --- |
| `jamfplatform_pro_sso_settings` | OIDC (Jamf Account admin sign-in) plus SAML (enrolment and Self Service SSO) |
| `jamfplatform_pro_sso_failover_url` | Adopts the tenant failover URL and exposes it as a sensitive output |
| `jamfplatform_pro_cloud_identity_provider` | Entra ID directory connection for group lookups — **not** a port, see below |

## Mutual exclusion

`jamfplatform_pro_sso_settings` is a singleton — its ID is always `"singleton"`. This
module, `identity-jamf-pro-okta`, and `configuration-jamf-pro-admin-sso` all manage it, so
**at most one may be active in a given apply**. The root module enforces this by deriving
all three counts from the single `idp_choice` string.

## Differences from the Okta module

Both modules write the same singleton, so they are deliberately near-identical. Everything
that differs, differs because Entra does:

| | Okta | Entra |
| --- | --- | --- |
| `idp_provider_type` | `OKTA` | `AZURE` |
| `group_attribute_name` | `http://schemas.xmlsoap.org/claims/Group` | `http://schemas.microsoft.com/ws/2008/06/identity/claims/groups` |
| `user_attribute_enabled` | always `false` | `true` when `idp_shortname` is set |
| `idp_shortname` accepted values | `mailNickName` | `mailNickName`, `onPremisesSamAccountName` |
| Directory integration | `jamfplatform_pro_ldap_server` (Okta LDAP interface) | `jamfplatform_pro_cloud_identity_provider` |

Because the two modules accept different `idp_shortname` sets, the **root variable carries
no validation** and each module validates its own accepted values. A `mailNickName` value
is valid for either; `onPremisesSamAccountName` fails fast on an Okta run.

## Derived rather than collected

- **Jamf Pro URL** — read from `data.jamfplatform_pro_jamf_pro_server_url`, replacing
  `var.jamfpro_instance_url`. Trailing slash trimmed before the SAML EntityID is built.
- **Entra tenant ID** — `split("/", var.entra_sso_metadata_url)[3]`, the same derivation
  the MSP module uses. The wizard never asks for it. `variables.tf` validates that the URL
  actually has a fourth segment, so a malformed URL fails with a readable message rather
  than an index-out-of-range error.

## The one addition beyond the port

MSP leaves Entra directory integration as a manual console step, because
`deploymenttheory/jamfpro` had no resource for it. `jamfplatform` ships
`jamfplatform_pro_cloud_identity_provider`, so this module creates the connection.

One step still cannot be automated: after the first apply, an **Entra global administrator
must grant consent** in *Settings > Cloud Identity Provider* in the Jamf Pro console. The
provider's own documentation says the same. Until they do, the connection exists but group
lookups return nothing. The `entra_tenant_id` output is there to make that step easy.

Set `entra_configure_cloud_identity_provider = false` to skip it and match MSP's
manual-only behaviour.

`tenant_id` forces replacement when changed, so re-running against a different Entra tenant
replaces the connection rather than silently no-op'ing.

## Scope: what this module deliberately does not do

| MSP resource | Covered by |
| --- | --- |
| macOS Platform SSO profile, Company Portal package and policy | `modules/management-microsoft-psso` |

Not covered anywhere, and **not** ported here:

- Jamf Connect login window and menu bar profiles. MSP builds these from
  `entra_oidcclientid`, `entra_oidcropgid`, `entra_oidcscopes` and `entra_ropgtenant`,
  falling back through `coalesce()` chains. The wizard collects all four plus
  `include_jamf_connect` and `jamf_connect_license_content`; none reaches a resource in
  this repo.
- `entra_enable_advanced_settings` is a wizard-only field. It gates the visibility of the
  OIDC fields on the form; no Terraform resource consumes it.

All are listed as open items in the root README.

## Entra-side prerequisites

None of this is created by Terraform; the wizard page walks the PSE through it.

1. A Jamf Pro enterprise application in Entra ID, from Microsoft's gallery entry.
2. The SAML Identifier (Entity ID) set to the `saml_entity_id` output.
3. A groups claim configured on the application, emitting group IDs.
4. If `idp_shortname` is used, a matching claim of that name on the application.
5. Global administrator consent for the Cloud Identity Provider connection, after apply.

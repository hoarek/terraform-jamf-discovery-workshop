# identity-jamf-pro-okta

Configures Jamf Pro's **own** identity settings for Okta Identity Engine. Ported from
`modules/Optional/IdentityProvider-Okta` in `jamf/msp-services-onboarding-tf`.

| Resource | Purpose |
| --- | --- |
| `jamfplatform_pro_sso_settings` | OIDC (Jamf Account admin sign-in) plus SAML (enrolment and Self Service SSO) |
| `jamfplatform_pro_sso_failover_url` | Adopts the tenant failover URL and exposes it as a sensitive output |
| `jamfplatform_pro_ldap_server` | Okta LDAP interface, for group-based scoping |

## Scope: what this module deliberately does not do

The MSP source module also deploys the device-side Okta payloads. Those are not ported,
because this repo already vendors public modules that cover the macOS half:

| MSP resource | Covered by |
| --- | --- |
| macOS SSO extension profile | `modules/management-macOS-SSOe-Okta` |
| Okta Verify package, policy, PSSO profiles | `modules/management-okta-psso` |

Not covered anywhere, and **not** ported here:

- The iOS Okta Verify VPP app and the iOS SSO extension profile. These need mobile
  device group IDs and VPP location content in the shape the MSP repo produces, which
  the modules in this repo do not expose. `okta_ios_secret_key` is collected by the
  wizard and currently reaches no resource.
- Jamf Connect login window and menu bar profiles. `include_jamf_connect`,
  `jamf_connect_license_content` and `okta_oidcclientid` are likewise collected and
  unconsumed.

Both are listed as open items in the root README.

## Mutual exclusion

`jamfplatform_pro_sso_settings` is a singleton — its ID is always `"singleton"`. This
module, `identity-jamf-pro-microsoft-entra`, and `configuration-jamf-pro-admin-sso` all
manage it, so **at most one may be active in a given apply**. The root module enforces
this by deriving all three counts from the single `idp_choice` string.

## Derived rather than collected

Two things the MSP module took as inputs are derived here instead:

- **Jamf Pro URL** — read from `data.jamfplatform_pro_jamf_pro_server_url`, replacing
  `var.jamfpro_instance_url`. The trailing slash is trimmed before the SAML EntityID is
  built from it.
- **Okta tenant host, LDAP hostname, base DN** — parsed out of
  `okta_sso_metadata_url` by the same regex the MSP module uses.

## Provider rename table

The `deploymenttheory/jamfpro` → `Jamf-Concepts/jamfplatform` move is not a simple
prefix change for the LDAP resource. Flat attributes moved into two nested attributes
and lost their `map_` prefixes.

| MSP (`jamfpro_ldap_server`) | Here (`jamfplatform_pro_ldap_server`) |
| --- | --- |
| `name` | `connection_settings.display_name` |
| `server_type` | `connection_settings.directory_service` |
| `open_close_timeout` | `connection_settings.connection_timeout` |
| `account { … }` | `connection_settings.account = { … }` |
| `map_object_class_to_any_or_all` | `object_class_limitation` |
| `map_user_id` / `map_username` / `map_realname` | `user_id` / `username` / `real_name` |
| `map_email_address` / `map_department` / `map_position` | `email_address` / `department` / `position` |
| `map_user_uuid` | `user_uuid` |
| `map_group_id` / `map_group_name` / `map_group_uuid` | `group_id` / `group_name` / `group_uuid` |
| `user_group_membership_stored_in` | `membership_location` |
| `map_user_membership_to_group_field` | `member_user_mapping` — see below |
| `user_group_membership_use_ldap_compare` | `use_ldap_compare` |
| `membership_scoping_optimization` | `membership_calculation_optimization` |

### The one judgement call

MSP sets `map_user_membership_to_group_field = "uniqueMember"` with
`user_group_membership_stored_in = "group object"`. The new provider splits that single
old field into two mode-specific ones:

- `group_membership_mapping` — "Group Membership Mapping", **User Object** mode
- `member_user_mapping` — "Member User Mapping", **Group Object** mode

`uniqueMember` is an attribute of `groupOfUniqueNames`, i.e. it lives on the group
object, so in `group object` mode it maps to `member_user_mapping`. A literal name match
would have put it in `group_membership_mapping` and silently produced a directory
connection that resolves no group memberships.

The MSP module also set `map_user_membership_use_dn`, `map_object_class_to_any_or_all`
and `search_scope` inside this block. The new provider documents all three as
User Object or Other mode fields, inert in `group object` mode, so they are omitted.

## Okta-side prerequisites

None of this is created by Terraform; the wizard page walks the PSE through it.

1. A SAML app for Jamf Pro from Okta's pre-configured catalogue entry.
2. The Okta LDAP interface enabled.
3. A read-only administrator account for `okta_service_account_username`.
4. A network zone containing the Jamf Cloud IP ranges, allowed **Every Time** in the
   Okta sign-on policy — otherwise Okta rate-limits or blocks the LDAP binds.

## Username mapping

`idp_shortname` couples two settings and must be consistent with Okta:

| `idp_shortname` | SAML `user_mapping` | LDAP `username` | Okta app username format |
| --- | --- | --- | --- |
| `""` (default) | `EMAIL` | `uid` | Okta Username |
| `mailNickName` | `USERNAME` | `mailNickName` | Okta Username prefix |

The wizard only exposes `idp_shortname` on the Entra page, so an Okta run always takes
the default row. The variable and its validation are kept because the MSP module
supports the other row and a future config may expose it.

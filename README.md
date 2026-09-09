# terraform-jamf-discovery-workshop

Terraform for the Discovery Workshop onboarder. Deployed by
`configs/discovery-workshop.json` in [`jamf/modular_onboarder`][onboarder]: the wizard
collects credentials, Apple service tokens and identity provider details, writes them into
a tfvars file, dispatches `.github/workflows/terraform-platform.yml` and polls this repo's
workflow run for artifacts.

Everything here targets the **Jamf Platform API** through the `Jamf-Concepts/jamfplatform`
provider, not the classic Jamf Pro API. Modules are vendored from
[`Jamf-Concepts/terraform-jamf-platform`][public] branch `ref-jamfplatform-onboarder`; two
things are ported from [`jamf/msp-services-onboarding-tf`][msp], which had them first.

[onboarder]: https://github.com/jamf/modular_onboarder
[public]: https://github.com/Jamf-Concepts/terraform-jamf-platform
[msp]: https://github.com/jamf/msp-services-onboarding-tf

## Running a workshop

Two settings matter, and they are not optional on a shared demo tenant.

```sh
export TF_CLI_ARGS_apply="-parallelism=1"
```

and in tfvars:

```json
{ "min_request_interval_ms": 100 }
```

Serialising apply and pacing requests is the difference between a clean run and a wall of
`429`s partway through. `terraform-platform.yml` already sets
`TF_CLI_ARGS_apply: "-parallelism=1 -no-color"` for dispatched runs;
`min_request_interval_ms` defaults to `100` in `variables.tf`, so a run that does not set
it still gets the pacing.

> The provider's request-pacing attribute is `min_request_interval_ms`. There is no
> `mandatory_request_delay_milliseconds` in `Jamf-Concepts/jamfplatform` — checked against
> `terraform providers schema -json`. If you are looking for the latter because another
> document mentions it, this is the same knob under its real name.

Running by hand:

```sh
terraform init
terraform apply -var-file=my.tfvars.json
```

## Platform API GA

The Jamf Platform API left public beta, and nothing carries over untouched. This repo
targets the GA gateway. What that means in practice:

| | Public beta | GA |
| --- | --- | --- |
| Gateway host | `https://{region}.apigw.jamf.com` | `https://{region}.api.jamfcloud.com`, host only, no path |
| Provider | `>= 0.27.0`, resolving to `0.28.1` | `0.29.0-rc.7`, pinned exactly |
| Scope | `tenant_id` | `environment_id` preferred, `tenant_id` still accepted |
| Credentials | beta API integration | replacement integration registered in Jamf Account |
| Jamf Security Cloud | separate `Jamf-Concepts/jsctfprovider` provider | `jamfplatform_security_cloud_*`, same gateway and integration |

**The version has to be pinned exactly.** `0.29.0-rc.7` is a pre-release, and Terraform
will not select one from a range — `~> 0.29`, `>= 0.29.0-rc.4` and an absent constraint all
resolve to `0.28.1`, which is bound to the retired beta gateway and cannot reach the
Platform API at all. `terraform init -upgrade` will not move onto a release candidate
either. `0.29.0-rc.4` is the functional floor, being the first release that speaks to the GA
host, but a constraint must name a version exactly to get any release candidate. When the
stable `0.29.0` ships, relax all 19 constraints at once:

```sh
grep -rl '0.29.0-rc.7' --include='*.tf' . | xargs sed -i '' 's/"0.29.0-rc.7"/"~> 0.29"/'
```

**Credentials must be replaced.** Beta API integration credentials were revoked at GA and a
beta client cannot be migrated. Register a replacement in the Jamf Account **Platform API
integrations** UI. Permissions there are organised by capability and action —
`device-groups:read`, not "Read Smart Computer Groups" — and each provider documentation
page carries a **Required Jamf permissions** table written the way the picker reads. Note
that an action covers only itself, so an integration that reads a record before modifying it
needs the read action as well as the update action, and the old computer/mobile privilege
pairs have collapsed into single device-level permissions: a computers-only integration is
no longer expressible.

**Scope.** Set `jamfplatform_environment_id` or `jamfplatform_tenant_id`, never both.
Validation in `variables.tf` enforces that, because the provider otherwise fails at
configure time with `Conflicting API Integration Scope`, and supplying the identifier that
does not match how the integration was registered is refused with `403 OWNERSHIP_FORBIDDEN`
even when both belong to the same customer. Environment scope is preferred: one integration
covers every tenant in the group. Neither is also rejected here — that would leave the
provider organization-scoped, which reaches only the `jamfplatform_account_*` family and
none of the modules in this repo.

**Resources removed from the provider.** `jamfplatform_pro_api_client` and
`jamfplatform_pro_api_role` are gone, their endpoints unpublished at GA to close a
privilege-escalation path. Both were used only by
`configuration-jamf-security-cloud-jamf-pro`, which is rewritten around
`jamfplatform_security_cloud_uem_connect` — see that module's README. A workspace whose
state still holds either type **cannot produce a plan of any kind** until the entries are
removed with `terraform state rm`; the migration commands are in the two Security Cloud
module READMEs. Workshop runs are unaffected, because the workflow starts from empty state
on every dispatch.

Nothing else in this repo was hit. Every other construct in use — `pro_sso_settings`,
`device_group`, both configuration profile types, `pro_jamf_protect`, `pro_ldap_server`, the
Apple token resources and `pro_jamf_pro_server_url` — survives GA unchanged.

Provider guide:
[Preparing for the Platform API GA](https://registry.terraform.io/providers/Jamf-Concepts/jamfplatform/latest/docs/guides/platform-api-ga).

## Conventions

- `required_version >= 1.14`. The floor is 1.14 rather than 1.11 because
  `configuration-jamf-security-cloud-all-services` drives an action from a
  `lifecycle { action_trigger }`, and `action` blocks do not exist before 1.14.
  `terraform-platform.yml` pins Terraform `1.16.1`.
- One provider, `Jamf-Concepts/jamfplatform`, pinned to `0.29.0-rc.7` in the root and in
  every module. Two instances: default plus alias `jpro`. The resolved version is recorded
  in `.terraform.lock.hcl`.
- Sub-modules declare `configuration_aliases = [jamfplatform.jpro]` and never configure a
  provider themselves.
- Gating is `count = var.include_<feature> == true ? 1 : 0`. Two deliberate exceptions,
  both explained below: the identity modules and the Apple token module.
- Module folders are `<area>-<platform>-<purpose>`, variables are snake_case, secrets carry
  `sensitive = true`, artefacts live under `support_files/`, and every module has a README.
- See `STYLE_GUIDE.md`, carried over from the public repo.

## Modules

Vendored unchanged from the public repo:

| Module | Flag |
| --- | --- |
| `onboarder-management-macOS` | `include_onboarder_management_macOS` |
| `onboarder-management-mobile` | `include_onboarder_management_mobile` |
| `configuration-jamf-pro-categories` | sub-module of `onboarder-management-macOS` |
| `configuration-jamf-pro-computer-management-settings` | sub-module |
| `configuration-jamf-pro-smart-groups` | sub-module |
| `management-macOS-rosetta` | sub-module |
| `management-iOS-configuration-profiles` | sub-module of `onboarder-management-mobile` |
| `endpoint-security-macOS-filevault` | `include_filevault` |
| `configuration-jamf-pro-jamf-protect` | `include_jamf_protect_trial_kickstart` |
| `configuration-jamf-pro-admin-sso` | `idp_choice = "none"` |
| `management-macOS-SSOe-Okta` | `include_ssoe_okta` — see Open items |
| `management-okta-psso` | `include_okta_psso` |
| `management-microsoft-psso` | `include_microsoft_psso` |

New in this repo:

| Module | Ported from | Gating |
| --- | --- | --- |
| `configuration-apple-service-tokens` | MSP `Core/Settings-DeviceEnrollments`, `Core/Settings-VolumePurchasingLocations`, `Core/Settings-DeviceEnrollmentsPublicKey` | none, see below |
| `identity-jamf-pro-okta` | MSP `Optional/IdentityProvider-Okta` | `idp_choice = "okta"` |
| `identity-jamf-pro-microsoft-entra` | MSP `Optional/IdentityProvider-Microsoft` | `idp_choice = "microsoft"` |

Rewritten for the Platform API GA — no longer mergeable from the public repo unchanged, so
each carries the reasoning and the migration commands in its own README:

| Module | Flag | Was | Is |
| --- | --- | --- | --- |
| `configuration-jamf-security-cloud-jamf-pro` | `include_jsc_uemc` | three `jamfplatform_pro_api_role`, one `jamfplatform_pro_api_client`, one `jsc_uemc` | one `jamfplatform_security_cloud_uem_connect` authenticating with `platform_tenant` |
| `configuration-jamf-security-cloud-all-services` | `include_jsc_all_services` | `jsc_ap` plists embedded in two Terraform-owned configuration profiles | `jamfplatform_security_cloud_activation_profile` plus two `..._activation_profile_deploy` actions |

The two are now ordered: deploying the activation profile's configuration profiles needs a
UEM Connect connector, so the root passes
`module.configuration-jamf-security-cloud-jamf-pro`'s connector ID into the all-services
module. That expresses the dependency as data rather than a `depends_on`, and the same value
answers whether UEM Connect was deployed at all. With `include_jsc_uemc` false the activation
profile is still minted and its code published as the `jsc_activation_code_credential`
output, for distribution as an enrollment link instead.

The closure was verified rather than assumed: every relative `source` inside `modules/`
resolves to a sibling directory in this repo, and `terraform init` pulls nothing from the
public repo at deploy time.

## Gating on `idp_choice`

`idp_choice` arrives as one string — `okta`, `microsoft`, `google` or `none`. The root
derives booleans from it rather than accepting three independent `include_idp_*` flags,
because `jamfplatform_pro_sso_settings` is a **singleton**: its resource ID is always
`"singleton"`, so two modules cannot co-manage it. Three booleans would let a caller select
Okta and Entra together and produce two Terraform resources fighting over one object.
Deriving from one string makes that combination unrepresentable.

| `idp_choice` | Writes the SSO singleton |
| --- | --- |
| `okta` | `identity-jamf-pro-okta` (OIDC + SAML, plus the Okta LDAP interface) |
| `microsoft` | `identity-jamf-pro-microsoft-entra` (OIDC + SAML, plus the Entra Cloud Identity Provider) |
| `none` | `configuration-jamf-pro-admin-sso` (OIDC only) |
| `google` | nothing yet — rejected by validation, see Open items |

`none` is not "do nothing": wizard page 2 tells the customer that Jamf Account admin SSO
will be enabled, so the OIDC-only module runs. Every branch has exactly one writer.

`include_jamf_pro_admin_sso` is a manual override that forces the OIDC-only module on and
takes precedence over the identity modules, for the same singleton reason.

## Apple service tokens

`configuration-apple-service-tokens` has **no `include_` flag**, deliberately. Each
resource inside is gated on its own token being non-empty, so the module is always
instantiated and `data.jamfplatform_pro_automated_device_enrollment_public_key` is readable
on the run that has no token yet — which is the run that needs it, because Apple will not
issue a token until you upload that public key.

The two tokens are **not** encoded symmetrically, which is the single easiest thing to get
wrong here:

| Token | On disk | After the onboarder's upload handler | Terraform |
| --- | --- | --- | --- |
| `.p7m` (ADE) | binary | base64 | pass through unchanged |
| `.vpptoken` (VPP) | already base64 text | base64 of base64 | exactly one `base64decode()` |

Both are write-only attributes with `*_wo_version` companions. Jamf Pro never returns them,
so Terraform cannot detect that the content changed; bump
`device_enrollment_token_wo_version` or `volume_purchasing_service_token_wo_version` to
force a re-upload.

Nothing in this repo creates a prestage enrolment. When one is added, it must depend on the
token through `module.configuration-apple-service-tokens.automated_device_enrollment_id`
rather than `depends_on`, so the reference carries the ordering.

APNs has no Apple API. The wizard gives instructions only, and this repo has no resource
for it.

## Checks

```sh
terraform fmt -recursive
terraform init -upgrade
terraform validate
python3 utils/check_config_variables.py --list-unused
```

All four pass clean. `check_config_variables.py` parses the onboarder config JSON, this
repo's `spec.yml` and `variables.tf`, and exits non-zero if any key has no matching root
variable. `terraform-platform.yml` runs it against the generated
`tfvars.auto.tfvars.json` before `terraform init`, so a wiring mistake fails with a
readable message instead of a wall of "Value for undeclared variable" warnings followed by
a confusing apply error.

`utils/migrate_provider_resources.py` is carried over from the public repo. It documents the
`deploymenttheory` → `jamfplatform` mappings and was run over the MSP modules before the
ports were written by hand; its output was read as a diff, not applied, because it does not
handle the nested-attribute rewrites (`oidc_settings = {}`, `connection_settings = {}`,
`scope = { targets = {} }`) that the schema change actually requires.

## Variable reconciliation

`variables.tf` declares 53 variables. Where the config, the public repo and MSP named
overlapping things differently, these are the calls made:

| Kept | Why |
| --- | --- |
| `okta_short_url`, `okta_org_name`, `okta_scep_url`, `okta_psso_client`, `okta_scep_username`, `okta_scep_password` | Live consumers: `management-okta-psso` templates all six into its configuration profiles. |
| `jamfpro_instance_url` | Kept as an optional override with `default = ""`, so this repo stays mergeable with the public repo, which takes it as an input. The root reads the real value from `data.jamfplatform_pro_jamf_pro_server_url` when it is empty. |

| Dropped | Why |
| --- | --- |
| `jsc_username`, `jsc_password`, `jsc_application_id`, `jsc_application_secret` | All four configured the `jsc` provider block, which is gone. Jamf Security Cloud is reached through the Platform API integration as `jamfplatform_security_cloud_*`, so there is no second credential set to hold. |
| `okta_client_id`, `okta_org_domain` | Their only references in the public repo are inside a commented-out `jsc_oktaidp` block in `configuration-jamf-security-cloud-all-services`. They are Jamf Trust settings, unrelated to `okta_oidcclientid`, and no live resource reads them. An activation profile's identity provider is not something `jamfplatform_security_cloud_activation_profile` can select either, so there is nothing to revive them for. |
| `okta_challenge_url` | Declared upstream, referenced nowhere. |

| Added | Why |
| --- | --- |
| `jamfplatform_environment_id` | The GA scope attribute. Mutually exclusive with `jamfplatform_tenant_id`, which became optional rather than required for the same reason. |
| `jsc_sync_refresh_interval_minutes`, `jsc_device_risk_uem_signaling_enabled` | The whole Security Cloud input surface now that credentials are gone. Neither is collected by the config; both default to the workshop's intent. |

Naming: MSP's `entra_sso_metadata_url` / `okta_sso_metadata_url` names were kept because the
config already uses them. MSP took the Jamf Pro URL as an input and the Entra tenant ID as a
separate field; both are derived here instead —
`data.jamfplatform_pro_jamf_pro_server_url` for the former,
`split("/", var.entra_sso_metadata_url)[3]` for the latter, which is what MSP does too.

`idp_shortname` carries **no validation at root**, on purpose: Okta accepts only
`mailNickName`, Entra also accepts `onPremisesSamAccountName`, and each module validates its
own set so the error message names the right provider.

## Open items

Things that are genuinely unresolved, rather than decided. None of these are guessed at in
the code.

**Google is not implemented.** `idp_choice` validation rejects `"google"` so a Google run
fails fast rather than silently deploying no SSO at all. All five `google_*` variables are
declared so the wiring check passes. The real obstacle is the Secure LDAP keystore:
`jamfplatform_pro_cloud_identity_provider` requires `google.server.keystore.file` as
**base64 of a PKCS#12 `.p12`** plus a `password`, and Google Workspace issues a **zip
containing a `.crt` and a `.key`**. Converting one to the other is an `openssl pkcs12
-export` call — not a Terraform operation, and not something HCL can fake. The config
collects `google_ldap_keystore_file_content` as a `.zip` and collects no keystore password
at all. Where MSP actually performs that conversion has not been established yet; that is
the next thing to find out, per the agreed order of work. The SAML half is
straightforward by comparison: `saml_settings.federation_metadata_file` takes raw base64
metadata XML directly, which is exactly what `google_sso_metadata_file_content` already is.

**`management-macOS-SSOe-Okta` cannot be safely enabled as vendored.** Its bundled
`.mobileconfig` has a Jamf demo Okta tenant and a specific SCEP URL and challenge path
hardcoded in it, and the module declares no Okta variables to override them with — all five
of its declared variables are unused. Enabling it against a customer tenant deploys a
profile pointing at the wrong Okta org. The public repo's own `spec.yml` says as much
("Please modify the following .mobileconfig payloads with your Organization's values"). It
is vendored and wired so the fix is local, but `include_ssoe_okta` defaults to `false` and
should stay there until the profile is templated the way `management-okta-psso` templates
its three.

**`management-okta-psso` needs inputs this config does not collect.** Its six Okta
variables are declared at root and passed through, but `discovery-workshop.json` has no
fields for them, so `include_okta_psso` defaults to `false`. `management-microsoft-psso`
has the opposite property — its profile is genuinely tenant-agnostic (the only GUID in it is
a `PayloadUUID`) so it needs no extra inputs — but it is still off by default because the
config does not ask for it.

**Wizard page 1 asks for the ADE token before the public key exists.** The Apple Service
Tokens section says "add a new Service using the Public Key supplied earlier", but the
public key comes from this Terraform run, which happens on page 3. On a first run the
operator has no key yet. The module handles this correctly — it is always instantiated, so
the key is exported on the tokenless run — but it makes the workshop a two-pass exercise:
run once to get `apple-device-enrollment-public-key`, fetch the token from Apple, run again
with it. Either the config's page order or its wording needs to change to say so.

**Collected but unconsumed.** These reach a real root variable, so the wiring check passes,
but no resource reads them. Every one of them is a Jamf Connect or iOS payload this repo has
no module for yet:

- `include_jamf_connect`, `jamf_connect_license_content`
- `okta_oidcclientid`, `okta_ios_secret_key`
- `entra_oidcclientid`, `entra_oidcscopes`, `entra_oidcropgid`, `entra_ropgtenant`
- `google_oidcclientid`, `google_oidcclientsecret`

`entra_enable_advanced_settings` is a different case: it is wizard-only by design, gating
the visibility of the advanced fields on the form. It is declared so the check passes and
will never have a consumer.

**Entra Cloud Identity Provider consent is manual.** The module registers the connection —
which MSP could not, because the old provider had no resource for it — but an Entra global
administrator must then grant consent in *Settings > Cloud Identity Provider* in the Jamf
Pro console. Group lookups return nothing until they do. The `entra_tenant_id` output exists
to make that step quick. Set `entra_configure_cloud_identity_provider = false` to skip
registration and match MSP's manual-only behaviour.

**Dead declarations in the vendored modules.** `management-okta-psso` declares 113 variables
and uses 6; `onboarder-management-macOS` and `onboarder-management-mobile` declare 87 each
and use 3, which they only pass down to sub-modules that do not read them. Vendored as-is,
on purpose: rewriting them would make every future merge from the public repo a manual
conflict resolution for no functional gain.

**Repo location.** This repo has no remote yet, so the config's `terraform_repo`,
`terraform_repo_branch` and `spec_url` had to be pointed at something that does not exist.
They now read `Jamf-Concepts/terraform-jamf-discovery-workshop` on `main` — `Jamf-Concepts`
chosen only because that is where the vendored Terraform modules live, not because it has
been confirmed. Org, repo name and branch all need deciding, and `spec_url` updating to
match. `workflow_file` is `terraform-platform.yml`, which is correct and unchanged.

**The stable `0.29.0` is not out yet.** Every constraint in this repo names
`0.29.0-rc.7` exactly, because Terraform will not select a pre-release from a range. Relax
them to `~> 0.29` once the stable release lands — the one-liner is under
[Platform API GA](#platform-api-ga). Until then `terraform init -upgrade` is a no-op here by
design.

**`jamfplatform_pro_sso_settings` may still move.** The Security Cloud half of the GA
migration is done; the SSO singleton came through GA unchanged, but it remains the surface
most likely to shift, and the three identity modules stay deliberately thin for that reason.

**Dead `jsc_*` variables remain in four sub-modules.** `onboarder-management-macOS`,
`onboarder-management-mobile`, `management-okta-psso` and `management-microsoft-psso` each
declare `jsc_application_id`, `jsc_application_secret` and a long list of
`include_jsc_ap_*` booleans. None was ever referenced by any resource, none is passed in by
the root, and none required the `jsc` provider — so removing the provider did not break
them. They are vendored dead weight, left in place on purpose: rewriting them would make
every future merge from the public repo a manual conflict resolution for no functional gain.
Worth a separate cleanup pass if that repo ever stops being a merge source.

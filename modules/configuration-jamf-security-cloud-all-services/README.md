# configuration-jamf-security-cloud-all-services

Creates the Jamf Security Cloud activation profile covering **Network Security** and
**Content Controls**, the two smart groups it is scoped to, and — where UEM Connect
is deployed — pushes its configuration profiles into Jamf Pro.

**Credentials: the Platform API integration only.** Jamf Security Cloud is reached
through the same gateway and the same integration as everything else in this repo.

## What it creates

| Where | What |
| --- | --- |
| Jamf Security Cloud | One activation profile, `Network Threat and Content Control`, with both service capabilities enabled for `ios` and `mac` |
| Jamf Pro | Smart computer group `All Computers` |
| Jamf Pro | Smart mobile device group `Supervised Mobile Devices` |
| Jamf Pro, via Jamf Security Cloud | The activation profile's macOS and supervised-iOS configuration profiles, scoped to those two groups |

The configuration profiles are created by **Jamf Security Cloud**, not by Terraform.
See [What changed at the Platform API GA](#what-changed-at-the-platform-api-ga).

## Required Jamf permissions

On the Platform API integration, in Jamf Account's permission picker:

| Category | Permission | Actions |
| --- | --- | --- |
| Enrollment | Activation profiles | Create, Read, Update, Delete |
| Global settings | UEM Connect configuration | Update |

The second row is what the deploy action needs. Device group writes are covered by
the permissions the rest of the repo already requires.

## Scoping — the one manual step

Both smart groups deliberately carry a dummy serial-number criterion, so an apply
reaches no real devices:

| Group | Remove this criterion |
| --- | --- |
| `All Computers` | `Serial Number` `like` `111222333444` |
| `Supervised Mobile Devices` | `Serial Number` `like` `111222333444555` |

Delete the criterion in Jamf Pro to turn the deployment on. The
`scope_groups_pending_criteria_removal` output repeats this, because the
configuration profile descriptions that used to carry the instruction are no longer
written by Terraform.

## Without UEM Connect

Deploying to Jamf Pro requires a UEM Connect connector that is connected to Jamf
Pro. The root supplies that in two inputs: `deploy_to_jamf_pro` (which is
`include_jsc_uemc`, and gates the deployment) and `uem_connect_id` from
`module.configuration-jamf-security-cloud-jamf-pro` (which orders the deployment
behind the connector). They are separate because the gate drives a `count` and so
must be known at plan time, while the connector's ID is a computed attribute and is
unknown on a first apply. With `include_jsc_uemc` false the module:

- still creates the activation profile and both smart groups,
- skips the deployment entirely,
- publishes the activation code as the sensitive `activation_code` output, for
  distribution as an enrollment link instead.

## What changed at the Platform API GA

This module used to read four `.mobileconfig` plists off a `jsc_ap` resource from the
separate `Jamf-Concepts/jsctfprovider` provider — `macosplist`, `supervisedplist`,
`unsupervisedplist`, `byodplist` — and embed them in `jamfplatform_pro_*_configuration_profile`
resources that Terraform created and owned.

The native `jamfplatform_security_cloud_activation_profile` exposes no plists.
Reading a profile returns the activation code and nothing else, so there is no
equivalent to that shape. Jamf Security Cloud builds and scopes the configuration
profiles itself, through the console's **Deploy to Jamf Pro** button, which
`jamfplatform_security_cloud_activation_profile_deploy` drives.

**Three things this costs, stated plainly:**

1. **Terraform no longer owns the configuration profiles.** They are not in state,
   `terraform plan` says nothing about them, and a destroy does not remove them.
   Delete them in Jamf Pro by hand.
2. **The long descriptions are gone.** The old profiles carried the "navigate to
   Smart Computer Groups and remove the serial number criteria" instruction in their
   description field. Jamf Security Cloud writes its own description, so that
   instruction moved to the `scope_groups_pending_criteria_removal` output and to
   [Scoping](#scoping--the-one-manual-step) above.
3. **The category is gone.** `Jamf Security Cloud - Activation Profiles` existed to
   file the Terraform-owned profiles. Jamf Security Cloud does not assign a category
   to the profiles it creates, so the resource would have created an empty category
   and nothing else.

The commented-out `jsc_oktaidp` block, and the `idptype = "NONE"` it paired with,
are not ported. An activation profile's identity provider is one of the settings this
resource cannot select — along with the end user application, in-app secure DNS
control, block pages, the expiration date and device location settings, all of which
take the Jamf Security Cloud default. Configure them in the console.

### Migrating an existing workspace

The old resources are still implemented, so this needs no `terraform state rm` —
`jsc_ap` belonged to a provider that is simply no longer required, and the two
configuration profiles are ordinary resources being removed from the configuration.
Terraform will therefore plan to **destroy** them on the next apply, then Jamf
Security Cloud will create its own replacements. Devices lose the configuration
briefly in between.

To avoid the gap, drop them from state first and delete them in the console once the
new ones are deployed:

```sh
terraform state rm 'module.configuration-jamf-security-cloud-all-services.jamfplatform_pro_macos_configuration_profile.all_services_macos'
terraform state rm 'module.configuration-jamf-security-cloud-all-services.jamfplatform_pro_mobile_device_configuration_profile.all_services_mobile_supervised'
terraform state rm 'module.configuration-jamf-security-cloud-all-services.jamfplatform_pro_category.jsc_all_services_profiles'
terraform state rm 'module.configuration-jamf-security-cloud-all-services.jsc_ap.all_services'
```

Both smart groups keep their addresses and are not touched.

Workshop runs are unaffected: the onboarder's workflow starts from empty state on
every dispatch.

## Known traps

- **Changing any setting replaces the activation profile** and mints a new activation
  code, invalidating anything already distributed under the old one. `paused` is the
  only exception.
- **Drift is invisible.** Jamf Security Cloud returns only the activation code when a
  profile is read, so a profile edited, paused or deleted in the console is not
  detected and `terraform plan` reports no changes.
- **Destroy cannot be confirmed** and does not remove the profile from the Jamf
  Security Cloud list, which grows with every profile Terraform has created here. A
  repeatedly re-run workshop tenant accumulates them.
- **Import is not supported** — Jamf Security Cloud does not return enough of an
  existing profile for Terraform to adopt it without immediately replacing it.
- **Deployment scope only accumulates.** `jamf_pro_group_ids` adds groups to the
  configuration profile's scope and never removes one. Narrow or clear a scope in
  Jamf Pro.

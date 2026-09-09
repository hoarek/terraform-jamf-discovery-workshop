# configuration-jamf-security-cloud-jamf-pro

Registers Jamf Pro as the Jamf Security Cloud **UEM Connect** connector, so device
inventory and group membership sync from Jamf Pro into Jamf Security Cloud and
device risk is signalled back.

**Credentials: the Platform API integration only.** No Jamf Pro client ID or secret,
no Jamf Security Cloud username or password. Jamf Security Cloud is reached through
the same gateway and the same integration as everything else in this repo.

## What it creates

- One `jamfplatform_security_cloud_uem_connect` connector, authenticating with
  `platform_tenant`: Jamf Security Cloud provisions and manages its own credentials
  on the Jamf Pro tenant, so no secret appears in the configuration or in state.
- Nothing in Jamf Pro. The tenant identifier is read with
  `data.jamfplatform_pro_tenant_id`, which resolves it from the provider's scope.

## Required Jamf permissions

On the Platform API integration, in Jamf Account's permission picker:

| Category | Permission | Actions |
| --- | --- | --- |
| Global settings | UEM Connect configuration | Create, Read, Update, Delete |

`403 NOT_ENTITLED` here is an entitlement gap rather than a missing permission — the
tenant does not hold the Security Cloud capability, and no permission will fix it.

## What changed at the Platform API GA

This module used to create three `jamfplatform_pro_api_role` resources (device sync,
risk signalling, activation profile deployment), a `jamfplatform_pro_api_client`
holding all three, and a `jsc_uemc` from the separate
`Jamf-Concepts/jsctfprovider` provider that consumed that client's ID and secret.

All four are gone:

- `/v1/api-integrations` and `/v1/api-roles` were unpublished at GA to close a
  privilege-escalation path — an API integration could create a client or role
  holding privileges it did not itself hold. The provider cannot call an endpoint
  that no longer exists, so `jamfplatform_pro_api_role` and
  `jamfplatform_pro_api_client` were removed. There is no Terraform replacement;
  the equivalent is the Platform API integrations UI in Jamf Account.
- That removed the module's whole reason for existing in its old shape, because
  `platform_tenant` needs no Jamf Pro credentials. The three roles are covered by
  the 31-privilege `JSC Connector` role Jamf Security Cloud creates for itself.
- The `jsc` provider is no longer used anywhere in this repo.

### Migrating an existing workspace

A workspace whose state still holds the removed types **cannot produce a plan of any
kind** — every operation fails, including ones unrelated to these resources, with:

```
Error: no schema available for jamfplatform_pro_api_client.<name> while reading
state; this is a bug in Terraform and should be reported
```

Despite the wording that is not a Terraform defect. Deleting the `resource` block is
not enough; the state entry remains. Remove the entries, which is a state-only
operation needing no schema and works either side of the upgrade:

```sh
terraform state list | grep -E 'jamfplatform_pro_api_(client|role)|jsc_uemc'
terraform state rm 'module.configuration-jamf-security-cloud-jamf-pro.jamfplatform_pro_api_client.jamfpro_api_integration_jsc'
terraform state rm 'module.configuration-jamf-security-cloud-jamf-pro.jamfplatform_pro_api_role.jamfpro_api_role_sync'
terraform state rm 'module.configuration-jamf-security-cloud-jamf-pro.jamfplatform_pro_api_role.jamfpro_api_role_signalling'
terraform state rm 'module.configuration-jamf-security-cloud-jamf-pro.jamfplatform_pro_api_role.jamfpro_api_role_deploy'
terraform state rm 'module.configuration-jamf-security-cloud-jamf-pro.jsc_uemc.initial_uemc'
```

`terraform state rm` only ends Terraform's management of the object. **The API
client and the three roles remain in place in Jamf Pro**, and the module will not
delete them on a later apply. Delete them by hand in **Settings > API roles and
clients** once the new connector is syncing.

Workshop runs are unaffected: the onboarder's workflow starts from empty state on
every dispatch, so there is nothing to migrate. This matters for a PSE running
locally against a tenant they have applied to before.

## Manual steps

**A tenant holds exactly one UEM Connect integration, and a second create is
refused.** Against a tenant that already has one — a demo tenant someone configured
in the console, or one this module applied to before — import instead of applying:

```sh
# the ID is not a value anyone would have written down; read it off the data source
terraform import \
  'module.configuration-jamf-security-cloud-jamf-pro.jamfplatform_security_cloud_uem_connect.jamf_pro' \
  <integration-id>
```

Then run `terraform plan` straight away. An import captures
`user_data_field_mapping` and `group_membership_mapping` from the tenant even though
this module declares neither, and the plan shows what would be cleared. Write those
values in before the next apply, or accept the clearing deliberately.

## Known trap: destroy leaves credentials behind

Destroying a `platform_tenant` connector **leaves a live Jamf Pro API integration in
place.** Jamf Security Cloud creates one named `JSC Connector` to authenticate with,
nothing removes it, and this provider holds no Jamf Pro credentials for that tenant
to remove it with. Every create/destroy cycle leaves one more enabled client
credential carrying the 31-privilege `JSC Connector` role — which includes writing
configuration profiles, computer and mobile device records, extension attributes and
group memberships.

A repeatedly re-run workshop tenant accumulates these fast. Audit **Settings > API
roles and clients** in Jamf Pro after any destroy and delete the orphans.

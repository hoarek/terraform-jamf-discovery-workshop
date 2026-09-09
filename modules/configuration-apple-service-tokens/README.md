# configuration-apple-service-tokens

Uploads the two Apple Business/School Manager service tokens the Discovery Workshop
collects, and exposes the ADE public key needed to obtain the first of them.

| Resource | Created when |
| --- | --- |
| `jamfplatform_pro_automated_device_enrollment` | `device_enrollment_token_content != ""` |
| `jamfplatform_pro_access_management_settings` | `device_enrollment_token_content != ""` |
| `jamfplatform_pro_volume_purchasing_location` | `volume_purchasing_service_token_content != ""` |

Both tokens are independent: supplying one and not the other is supported.

## Gating

This module has no `include_*` flag and is always instantiated. Each resource is gated
on whether its token was actually supplied, so an extra switch would only add a way to
silently discard an uploaded token. The `data` source is always read so the public key
output is available on runs where no token exists yet — which is the run that needs it.

## Token encoding

The two tokens are encoded differently and this is easy to get wrong.

| Token | On disk | Wizard sends | This module passes |
| --- | --- | --- | --- |
| ADE `.p7m` | binary | `base64(bytes)` | value unchanged |
| VPP `.vpptoken` | base64 text | `base64(base64 text)` | `base64decode(value)` |

The provider base64-decodes `server_token` itself, so the ADE value is passed straight
through. It does *not* decode `service_token` — that attribute wants the `.vpptoken`
text as-is — so the wizard's extra layer of encoding is removed here with a single
`base64decode`. This mirrors `Settings-VolumePurchasingLocations` in
`msp-services-onboarding-tf`, whose variable is likewise described as "double base64
encoded".

If a future config sets `skip_base64_encode: true` on the VPP upload field (the
onboarder supports this per-field), the `base64decode` here must be removed.

## First-run ordering

Apple will not issue an ADE server token until Jamf Pro's public key has been registered
in Apple Business/School Manager, so a first-ever run is necessarily two passes:

1. Apply with no ADE token. Collect `automated_device_enrollment_public_key` from the
   root outputs, which the workflow publishes as an artifact.
2. Create the MDM server in Apple Business/School Manager using that key, download the
   `.p7m`, and apply again with `device_enrollment_token_content` set.

Prestage enrollment resources must not be applied before the token upload. Take that
dependency through `automated_device_enrollment_id` rather than `depends_on`, so
Terraform orders the graph from real data flow.

## Timeouts

`create` and `update` are raised above the provider defaults because both resources
block on an Apple-side sync that routinely exceeds five minutes on first use.

## Rotation

`server_token` and `service_token` are write-only: Jamf Pro never returns them, so
Terraform cannot detect drift. To re-send a renewed token, replace the content variable
*and* bump the matching `*_wo_version` integer. Changing the content alone does nothing.

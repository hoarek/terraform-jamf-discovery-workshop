output "automated_device_enrollment_public_key" {
  description = "Base64-encoded Jamf Pro ADE public key. Upload this to Apple Business/School Manager to obtain the .p7m server token."
  value       = data.jamfplatform_pro_automated_device_enrollment_public_key.current.public_key
}

# Prestage enrollment resources reference an ADE instance by ID. Consuming this output
# creates a real data dependency, so the token upload is guaranteed to land before any
# prestage that uses it. Prefer this over depends_on.
output "automated_device_enrollment_id" {
  description = "Jamf Pro ID of the Automated Device Enrollment instance, or null when no ADE token was supplied."
  value       = one(jamfplatform_pro_automated_device_enrollment.default[*].id)
}

output "automated_device_enrollment_server_uuid" {
  description = "Apple-recorded MDM server UUID for the ADE instance, or null when no ADE token was supplied."
  value       = one(jamfplatform_pro_automated_device_enrollment.default[*].server_uuid)
}

output "automated_device_enrollment_token_expiration_date" {
  description = "Expiration date (YYYY-MM-DD) of the uploaded ADE server token, or null when no ADE token was supplied."
  value       = one(jamfplatform_pro_automated_device_enrollment.default[*].token_expiration_date)
}

output "volume_purchasing_location_id" {
  description = "Jamf Pro ID of the Volume Purchasing location, or null when no content token was supplied."
  value       = one(jamfplatform_pro_volume_purchasing_location.default[*].id)
}

output "volume_purchasing_token_expiration" {
  description = "Expiration timestamp of the uploaded VPP service token, or null when no content token was supplied."
  value       = one(jamfplatform_pro_volume_purchasing_location.default[*].token_expiration)
}

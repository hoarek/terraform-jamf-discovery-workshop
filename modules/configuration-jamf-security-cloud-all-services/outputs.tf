###############################################################################
# Outputs
###############################################################################

# The activation code is a credential: anyone holding it can enrol a device, so the
# provider marks the attribute sensitive and any output carrying it must be too.
output "activation_code" {
  description = "Activation code end users enrol Jamf Trust against. Distribute as a link where UEM Connect is not deployed and the configuration profiles were therefore not pushed into Jamf Pro."
  value       = jamfplatform_security_cloud_activation_profile.all_services.id
  sensitive   = true
}

output "all_macs_jamf_pro_id" {
  description = "Jamf Pro smart group ID for the all-Macs device group. Consumed by the root module's deploy action."
  value       = jamfplatform_device_group.all_macs.jamf_pro_id
}

output "all_mobile_devices_jamf_pro_id" {
  description = "Jamf Pro smart group ID for the all-mobile-devices group. Consumed by the root module's deploy action."
  value       = jamfplatform_device_group.all_mobile_devices.jamf_pro_id
}

# Both groups ship with a dummy serial-number criterion so a workshop apply reaches
# no devices. Naming the groups in an output puts the follow-up step in front of the
# operator, which is the job the configuration profile descriptions used to do before
# Jamf Security Cloud started creating those profiles itself.
output "scope_groups_pending_criteria_removal" {
  description = "Smart groups scoped to the deployed configuration profiles. Each carries a dummy serial-number criterion that stops it matching real devices. Remove that criterion in Jamf Pro to turn the deployment on."
  value = {
    computer = {
      name        = jamfplatform_device_group.all_macs.name
      jamf_pro_id = jamfplatform_device_group.all_macs.jamf_pro_id
      remove      = "Serial Number like 111222333444"
    }
    mobile = {
      name        = jamfplatform_device_group.all_mobile_devices.name
      jamf_pro_id = jamfplatform_device_group.all_mobile_devices.jamf_pro_id
      remove      = "Serial Number like 111222333444"
    }
  }
}

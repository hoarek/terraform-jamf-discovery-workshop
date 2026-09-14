## Call Terraform provider
terraform {
  required_version = ">= 1.11"
  required_providers {
    jamfplatform = {
      source                = "jamf/jamfplatform"
      version               = "0.32.0"
      configuration_aliases = [jamfplatform.jpro]
    }
  }
}

## Create Jamf Protect <> Jamf Pro integration
resource "jamfplatform_pro_jamf_protect" "protect_integration" {
  client_id           = var.jamfprotect_client_id
  password            = var.jamfprotect_client_password
  auto_install        = true
  api_url             = var.jamfprotect_url
  password_wo_version = 1
  timeouts = {
    create = "90s"
  }
}

## Create Category
resource "jamfplatform_pro_category" "category_jamfprotect_security" {
  name     = "Security - Jamf Protect"
  priority = 9
}

# Create Smart Group and Congfiguration Profile to identify Sequoia Macs and make Jamf Protect a non removable system extension

resource "jamfplatform_device_group" "group_sequoia_computers_jamf_protect" {
  name        = "Macs on MacOS Sequoia (Jamf Protect System Extension Enforcement)"
  group_type  = "smart"
  device_type = "computer"
  criteria = [
    {
      criteria = "Operating System Version"
      operator = "like"
      value    = "15."
    },
  ]
}

## Jamf Protect extension attributes
#
# Three SCRIPT EAs surface Protect plan state into Jamf Pro inventory, which
# lets you build smart groups and target policy on plan health. Scripts use
# defaults read against the Protect preferences plist; verify the key names
# against your Protect version before deploying.

resource "jamfplatform_pro_computer_extension_attribute" "protect_plan_hash" {
  provider = jamfplatform.jpro

  name              = "Jamf Protect - Plan Hash"
  data_type         = "STRING"
  input_type        = "SCRIPT"
  inventory_display = "OPERATING_SYSTEM"
  script            = <<-SCRIPT
    #!/bin/bash
    result=$(defaults read /Library/Preferences/com.jamf.protect.preferences planHash 2>/dev/null)
    echo "<result>$${result}</result>"
  SCRIPT
}

resource "jamfplatform_pro_computer_extension_attribute" "protect_plan_id" {
  provider = jamfplatform.jpro

  name              = "Jamf Protect - Plan ID"
  data_type         = "STRING"
  input_type        = "SCRIPT"
  inventory_display = "OPERATING_SYSTEM"
  script            = <<-SCRIPT
    #!/bin/bash
    result=$(defaults read /Library/Preferences/com.jamf.protect.preferences planId 2>/dev/null)
    echo "<result>$${result}</result>"
  SCRIPT
}

resource "jamfplatform_pro_computer_extension_attribute" "protect_smart_group_membership" {
  provider = jamfplatform.jpro

  name              = "Jamf Protect - Smart Group Membership"
  data_type         = "STRING"
  input_type        = "SCRIPT"
  inventory_display = "OPERATING_SYSTEM"
  # The Protect agent writes its smart-group memberships to the preferences
  # plist as a comma-separated list under the key "smartGroups". Adjust the
  # key name if your Protect version uses a different schema.
  script = <<-SCRIPT
    #!/bin/bash
    result=$(defaults read /Library/Preferences/com.jamf.protect.preferences smartGroups 2>/dev/null \
      | tr -d '()' | tr -s ' ' ',' | sed 's/^,//;s/,$//')
    echo "<result>$${result}</result>"
  SCRIPT
}

resource "jamfplatform_pro_macos_configuration_profile" "jamfpro_macos_configuration_profile_jamf_protect_system_extension" {

  general = {
    name                = "Jamf Protect System Extension Enforcement"
    description         = "This configuration profile prevents users from disabling the Jamf Protect System Extension"
    level               = "Computer Level"
    redeploy_on_update  = "Newly Assigned"
    distribution_method = "Install Automatically"
    payloads            = file("${path.module}/support_files/non_removable_system_extension_jamf_protect.mobileconfig")
    user_removable      = false
    category_id         = jamfplatform_pro_category.category_jamfprotect_security.id
  }
  scope = {
    targets = {
      all_computers      = false
      computer_group_ids = [jamfplatform_device_group.group_sequoia_computers_jamf_protect.jamf_pro_id]
    }
  }
}

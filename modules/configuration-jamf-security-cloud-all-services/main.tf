## Call Terraform provider
terraform {
  required_version = ">= 1.14"
  required_providers {
    jamfplatform = {
      source                = "Jamf-Concepts/jamfplatform"
      version               = "~> 0.29"
      configuration_aliases = [jamfplatform.jpro]
    }
  }
}

###############################################################################
# Activation profile
#
# Before the Platform API GA this module read four .mobileconfig plists off a jsc_ap
# resource (macosplist, supervisedplist, unsupervisedplist, byodplist) and embedded
# them in configuration profiles Terraform created and owned in Jamf Pro.
#
# The native jamfplatform_security_cloud_activation_profile exposes no plists —
# reading a profile returns the activation code and nothing else — so that shape has
# no equivalent. Jamf Security Cloud builds and scopes the configuration profiles
# itself, via the console's "Deploy to Jamf Pro" button, which the
# jamfplatform_security_cloud_activation_profile_deploy action drives. Terraform
# therefore no longer owns those profiles: it owns the activation profile and the
# smart groups the deployment is scoped to. See README.md for what that costs.
#
# This resource manages a deliberately small part of an activation profile. The end
# user application, the whole authentication step including the identity provider,
# in-app secure DNS control, block pages, the expiration date and device location
# settings are configurable in Jamf Security Cloud only; this profile takes the Jamf
# Security Cloud default for each. That is why the commented-out jsc_oktaidp block
# and its idptype = "NONE" companion are gone rather than ported — an identity
# provider is not something this resource can select.
#
# Three behaviours to know before editing it. Changing any setting other than
# `paused` REPLACES the profile and mints a new activation code, invalidating
# anything already distributed. A profile edited or deleted in the Jamf Security
# Cloud console is not detected — plan reports no changes. And a destroy cannot be
# confirmed and does not remove the profile from the Jamf Security Cloud list, which
# grows with every profile Terraform has ever created here.
###############################################################################

resource "jamfplatform_security_cloud_activation_profile" "all_services" {
  provider = jamfplatform.jpro

  name      = "Network Threat and Content Control"
  platforms = ["ios", "mac"]

  capabilities = {
    network_security = true
    content_controls = true
    note             = "Managed by Terraform — terraform-jamf-discovery-workshop"
  }
}

###############################################################################
# Scope targets
#
# Both groups deliberately carry a dummy serial-number criterion so that a workshop
# apply reaches no real devices. Removing it is the step that turns the deployment
# on, and it is a console step: see README.md and the module's outputs.
#
# jamf_pro_id is the classic-API numeric ID, which is what the deploy action's
# jamf_pro_group_ids wants — bare, unlike uem_group_id on the UEM Connect resource,
# which wants the same group written as "computer_12". The two are not
# interchangeable.
###############################################################################

resource "jamfplatform_device_group" "all_macs" {
  provider = jamfplatform.jpro

  name        = "All Computers"
  group_type  = "smart"
  device_type = "computer"

  criteria = [
    {
      criteria = "Computer Group"
      operator = "member of"
      value    = "All Managed Clients"
    },
    {
      criteria = "Serial Number"
      operator = "like"
      value    = "111222333444"
    },
  ]
}

resource "jamfplatform_device_group" "all_mobile_devices" {
  provider = jamfplatform.jpro

  name        = "*All Mobile Devices"
  group_type  = "smart"
  device_type = "mobile"

  # Exclude Apple Watch (watchOS) and Apple Vision Pro (visionOS); keep every
  # iPhone, iPad, and iPod touch. The dummy serial criterion stops the group
  # matching real devices until an operator removes it from Jamf Pro — same
  # pattern as all_macs above.
  criteria = [
    {
      criteria = "OS Version"
      operator = "not like"
      value    = "watchOS"
    },
    {
      criteria = "OS Version"
      operator = "not like"
      value    = "visionOS"
    },
    {
      criteria = "Serial Number"
      operator = "like"
      value    = "111222333444"
    },
  ]
}

###############################################################################
# Deploy to Jamf Pro
#
# One deployment per operating system, so one action each. macOS scopes to computer
# groups and iOS to mobile device groups; naming a group of the wrong kind for the
# chosen os is refused.
#
# The unsupervised and BYOD iOS forms (os = "ios_unsupervised", "ios_byod") are
# available and not deployed, matching the commented-out unsupervisedplist and
# byodplist profiles this module carried before: neither has a smart group here to
# scope to, and a first deployment naming no group scopes the profile to nothing
# while still reporting success.
#
# Scope only ever accumulates. jamf_pro_group_ids adds groups and never removes one,
# and omitting it leaves an existing scope untouched. To narrow or clear a scope,
# edit the configuration profile in Jamf Pro.
###############################################################################

action "jamfplatform_security_cloud_activation_profile_deploy" "macos" {
  provider = jamfplatform.jpro

  config {
    activation_profile_code = jamfplatform_security_cloud_activation_profile.all_services.id
    os                      = "macos"
    jamf_pro_group_ids      = [jamfplatform_device_group.all_macs.jamf_pro_id]
  }
}

action "jamfplatform_security_cloud_activation_profile_deploy" "ios_supervised" {
  provider = jamfplatform.jpro

  config {
    activation_profile_code = jamfplatform_security_cloud_activation_profile.all_services.id
    os                      = "ios_supervised"
    jamf_pro_group_ids      = [jamfplatform_device_group.all_mobile_devices.jamf_pro_id]
  }
}

# Actions run only when something triggers them, so the trigger is what gates
# deployment — the action blocks above are inert without it.
#
# Two inputs, doing two different jobs, and they are not interchangeable.
#
# deploy_to_jamf_pro drives count, and has to be a value that is known at plan time.
# uem_connect_id is a computed attribute of a resource in another module, so on a
# first apply it is unknown during plan, and a count depending on it fails outright
# with "The count value depends on resource attributes that cannot be determined
# until apply". The root therefore passes var.include_jsc_uemc here, which is a plain
# root variable and always known.
#
# uem_connect_id then carries the ordering. Deploying requires a UEM Connect
# integration that is connected to Jamf Pro, and nothing in the action's own
# arguments names one; referencing the connector ID makes that a data dependency
# rather than a depends_on reaching across modules. Being unknown at plan time is
# fine for an attribute, which is exactly why the gate and the dependency are split.
#
# input also carries the activation code, so that a replaced activation profile — any
# edit other than `paused` mints a new one — changes this resource and fires
# after_update, redeploying rather than leaving Jamf Pro holding a configuration
# profile for a code that no longer works. Re-running a deployment is safe: it
# updates the configuration profile Jamf Security Cloud already created instead of
# adding a second one, and recreates it if it was deleted in Jamf Pro.
###############################################################################
# Jamf Trust mobile app
#
# Scoped to *All Mobile Devices so every enrolled iPhone/iPad receives it
# alongside the JSC network security and content control profiles.
#
# version = "0" instructs Jamf Pro to accept any build; keep_app_updated_on_devices
# then keeps the installed copy current from the App Store.
#
# VPP device-based licence assignment is a separate jamfplatform_pro_vpp_assignment
# resource that requires a VPP admin account ID. That resource cannot be written
# until the VPP token module is ported — add it once the token handling is in place.
# Without VPP, supervised devices will receive the install command but Apple may
# prompt the user to sign in with an Apple ID for a free-app redemption.
###############################################################################

resource "jamfplatform_pro_mobile_device_app" "jamf_trust" {
  provider = jamfplatform.jpro

  general = {
    name                        = "Jamf Trust"
    version                     = "0"
    bundle_id                   = "com.jamf.trust"
    os_type                     = "iOS"
    is_free                     = true
    deployment_type             = "Install Automatically/Prompt Users to Install"
    deploy_as_managed_app       = true
    keep_app_updated_on_devices = true
    take_over_management        = false
  }

  scope = {
    targets = {
      mobile_device_group_ids = [jamfplatform_device_group.all_mobile_devices.jamf_pro_id]
    }
  }
}

resource "terraform_data" "deploy_to_jamf_pro" {
  count = var.deploy_to_jamf_pro ? 1 : 0

  input = {
    uem_connect_id          = var.uem_connect_id
    activation_profile_code = jamfplatform_security_cloud_activation_profile.all_services.id
  }

  lifecycle {
    action_trigger {
      events = [after_create, after_update]
      actions = [
        action.jamfplatform_security_cloud_activation_profile_deploy.macos,
        action.jamfplatform_security_cloud_activation_profile_deploy.ios_supervised,
      ]
    }
  }
}

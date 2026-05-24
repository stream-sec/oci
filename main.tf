# Stream Security OCI integration — Resource Manager stack.
# Creates a read-only API user/group/policy in your tenancy so Stream Security
# can inventory and posture-check resources via the OCI APIs.
#
# This module is intentionally minimal. It runs in OCI Resource Manager which
# auto-injects credentials via its own service principal — no auth field is
# needed on the provider block.

terraform {
  required_version = ">= 1.3"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
}

# tenancy_ocid + current_user_ocid + region are auto-populated by Resource
# Manager when the stack is launched via the "Deploy to Oracle Cloud" button.
variable "tenancy_ocid" {
  type        = string
  description = "Tenancy OCID (auto-populated by Resource Manager)."
}

variable "current_user_ocid" {
  type        = string
  description = "Launching user's OCID (auto-populated by Resource Manager; unused)."
}

variable "region" {
  type        = string
  description = "OCI region (auto-populated by Resource Manager)."
}

# external_id + account_token come from the Stream Security wizard via
# zipUrlVariables when the magic launch URL is built.
variable "external_id" {
  type        = string
  description = "Stream Security account identifier — passed via zipUrlVariables."
}

variable "account_token" {
  type        = string
  sensitive   = true
  description = "Stream Security per-account token — passed via zipUrlVariables."
}

provider "oci" {
  region = var.region
}

resource "oci_identity_group" "stream_security_readers" {
  compartment_id = var.tenancy_ocid
  name           = "stream-security-readers-${var.external_id}"
  description    = "Group granting Stream Security read access to this tenancy."
}

resource "oci_identity_user" "stream_security_api_user" {
  compartment_id = var.tenancy_ocid
  name           = "stream-security-api-${var.external_id}"
  description    = "API-only user used by Stream Security to scan this tenancy."
  email          = "noreply+${var.external_id}@stream.security"
}

resource "oci_identity_user_group_membership" "stream_security_membership" {
  user_id  = oci_identity_user.stream_security_api_user.id
  group_id = oci_identity_group.stream_security_readers.id
}

resource "oci_identity_policy" "stream_security_read_policy" {
  compartment_id = var.tenancy_ocid
  name           = "stream-security-read-policy-${var.external_id}"
  description    = "Read-only access for Stream Security."
  statements = [
    "Allow group ${oci_identity_group.stream_security_readers.name} to inspect all-resources in tenancy",
    "Allow group ${oci_identity_group.stream_security_readers.name} to read all-resources in tenancy",
    "Allow group ${oci_identity_group.stream_security_readers.name} to read audit-events in tenancy",
  ]
}

output "stream_security_user_ocid" {
  value       = oci_identity_user.stream_security_api_user.id
  description = "Paste this user OCID back into the Stream Security wizard."
}

output "stream_security_account_token" {
  value       = var.account_token
  sensitive   = true
  description = "Per-account token (passed in via zipUrlVariables; echoed here for convenience)."
}

# Stream Security OCI integration — Resource Manager stack.
#
# Creates a read-only API user, group, and IAM policy in your tenancy and
# generates a fresh RSA API key for that user. The user OCID, key fingerprint,
# and private key are exposed as stack outputs so you can paste them back into
# the Stream Security onboarding wizard.

terraform {
  required_version = ">= 1.3"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}

# Auto-populated by Resource Manager from the launching user's session.
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

# Passed by the Stream Security wizard via zipUrlVariables.
variable "external_id" {
  type        = string
  description = "Stream Security account identifier."
}

variable "account_token" {
  type        = string
  sensitive   = true
  description = "Stream Security per-account token (echoed in outputs for the wizard)."
}

provider "oci" {
  region = var.region
}

resource "oci_identity_group" "stream_security_readers" {
  compartment_id = var.tenancy_ocid
  name           = "stream-security-readers-${var.external_id}"
  description    = "Stream Security read access."
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

# Generate a fresh RSA keypair and upload the public half as the user's API key.
# Private key is exposed as a sensitive output so the customer can paste it
# back into the Stream Security wizard.
resource "tls_private_key" "stream_security_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "oci_identity_api_key" "stream_security_api_key" {
  user_id   = oci_identity_user.stream_security_api_user.id
  key_value = tls_private_key.stream_security_key.public_key_pem
}

output "stream_security_user_ocid" {
  value       = oci_identity_user.stream_security_api_user.id
  description = "User OCID — paste into the Stream Security wizard."
}

output "stream_security_fingerprint" {
  value       = oci_identity_api_key.stream_security_api_key.fingerprint
  description = "API key fingerprint — paste into the Stream Security wizard."
}

output "stream_security_private_key" {
  value       = tls_private_key.stream_security_key.private_key_pem
  sensitive   = true
  description = "API private key (PEM) — paste into the Stream Security wizard. Sensitive."
}

output "stream_security_account_token" {
  value       = var.account_token
  sensitive   = true
  description = "Stream Security account token (echoed for convenience)."
}

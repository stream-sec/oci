# stream-security / oci

OCI Resource Manager Terraform module used by the Stream Security platform
to onboard customer OCI tenancies.

Customers do not interact with this repo directly — the Stream Security UI
generates a "Deploy to Oracle Cloud" magic-launch URL pointing at the
`main.tf.zip` artifact in releases, with `zipUrlVariables` carrying the
per-customer `external_id` and `account_token`.

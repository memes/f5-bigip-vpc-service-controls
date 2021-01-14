variable "tf_sa_email" {
  type        = string
  default     = ""
  description = <<EOD
The fully-qualified email address of the Terraform service account to use for
resource creation via account impersonation. If left blank, the default, then
the invoker's account will be used.

E.g. if you have permissions to impersonate:

tf_sa_email = "terraform@PROJECT_ID.iam.gserviceaccount.com"
EOD
}

variable "tf_sa_token_lifetime_secs" {
  type        = number
  default     = 600
  description = <<EOD
The expiration duration for the service account token, in seconds. This value
should be high enough to prevent token timeout issues during resource creation,
but short enough that the token is useless replayed later. Default value is 600
(10 mins).
EOD
}

variable "org_id" {
  type        = string
  description = <<EOD
The GCP Organisation ID that will have a policy applied.
EOD
}

variable "billing_id" {
  type        = string
  description = <<EOD
The GCP billing identifier to use for created project.
EOD
}

variable "region" {
  type        = string
  default     = "us-west1"
  description = <<EOD
The region to deploy test resources. Default is 'us-west1'.
EOD
}

variable "restricted_services" {
  type        = list(string)
  default     = []
  description = <<EOD
The list of GCP services to restrict in the created policy.
EOD
}

variable "tf_sa_impersonators" {
  type        = list(string)
  default     = []
  description = <<EOD
A list of fully-qualified IAM accounts that will be allowed to impersonate the
project-specific Terraform service account. If no accounts are supplied,
impersonation will not be setup by the script.
E.g.
tf_sa_impersonators = [
  "group:devsecops@example.com",
  "group:admins@example.com",
  "user:jane@example.com",
  "serviceAccount:ci-cd@project.iam.gserviceaccount.com",
]
EOD
}

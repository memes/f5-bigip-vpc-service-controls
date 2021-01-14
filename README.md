# Installing F5 BIG-IP to a project with VPC Service Controls from F5's published images
<!-- spell-checker: ignore markdownlint -->

<!-- markdownlint-disable MD033 MD034 -->
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| terraform | ~> 0.13, < 0.14 |
| google | ~> 3.48 |
| google | ~> 3.48 |
| google-beta | ~> 3.48 |

## Providers

| Name | Version |
|------|---------|
| google | ~> 3.48 ~> 3.48 |
| google.executor | ~> 3.48 ~> 3.48 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| billing\_id | The GCP billing identifier to use for created project. | `string` | n/a | yes |
| org\_id | The GCP Organisation ID that will have a policy applied. | `string` | n/a | yes |
| region | The region to deploy test resources. Default is 'us-west1'. | `string` | `"us-west1"` | no |
| restricted\_services | The list of GCP services to restrict in the created policy. | `list(string)` | `[]` | no |
| tf\_sa\_email | The fully-qualified email address of the Terraform service account to use for<br>resource creation via account impersonation. If left blank, the default, then<br>the invoker's account will be used.<br><br>E.g. if you have permissions to impersonate:<br><br>tf\_sa\_email = "terraform@PROJECT\_ID.iam.gserviceaccount.com" | `string` | `""` | no |
| tf\_sa\_impersonators | A list of fully-qualified IAM accounts that will be allowed to impersonate the<br>project-specific Terraform service account. If no accounts are supplied,<br>impersonation will not be setup by the script.<br>E.g.<br>tf\_sa\_impersonators = [<br>  "group:devsecops@example.com",<br>  "group:admins@example.com",<br>  "user:jane@example.com",<br>  "serviceAccount:ci-cd@project.iam.gserviceaccount.com",<br>] | `list(string)` | `[]` | no |
| tf\_sa\_token\_lifetime\_secs | The expiration duration for the service account token, in seconds. This value<br>should be high enough to prevent token timeout issues during resource creation,<br>but short enough that the token is useless replayed later. Default value is 600<br>(10 mins). | `number` | `600` | no |

## Outputs

| Name | Description |
|------|-------------|
| bigip\_sa | Service account to use for BIG-IP instances. |
| project\_id | The generated project identifier. |
| region | The GCE region to use. |
| subnets | The set of generated subnets to use with BIG-IP. |
| tf\_sa | Service account to use for Terraform in project. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
<!-- markdownlint-enable MD033 MD034 -->

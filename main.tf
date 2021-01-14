# This example is only supported on Terraform 0.13 due to upstream module dependencies.
terraform {
  required_version = "~> 0.13, < 0.14"
}

# Service account impersonation (if enabled) and Google provider setup is
# handled in providers.tf

module "project" {
  source                             = "terraform-google-modules/project-factory/google"
  version                            = "10.0.1"
  billing_account                    = var.billing_id
  name                               = "vpc-controls-bigip"
  random_project_id                  = true
  org_id                             = var.org_id
  vpc_service_control_attach_enabled = false
  default_service_account            = "disable"
  activate_apis = [
    "compute.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
  ]
  auto_create_network = false
}

module "policy" {
  source      = "terraform-google-modules/vpc-service-controls/google"
  version     = "2.0.0"
  parent_id   = var.org_id
  policy_name = "vpc_svc_controls"
}

module "policy_level" {
  source  = "terraform-google-modules/vpc-service-controls/google//modules/access_level"
  version = "2.0.0"
  policy  = module.policy.policy_id
  name    = "vpc_svc_controls_tf"
  members = formatlist("serviceAccount:%s", compact([
    var.tf_sa_email,
    google_service_account.tf.email,
  ]))
}

module "service_perimeter" {
  source              = "terraform-google-modules/vpc-service-controls/google//modules/regular_service_perimeter"
  version             = "2.0.0"
  policy              = module.policy.policy_id
  perimeter_name      = "vpc_svc_controls_perimeter"
  description         = "Enforcing VPC service control policy for BIG-IP"
  access_levels       = [module.policy_level.name]
  restricted_services = var.restricted_services
  resources = [
    module.project.project_number
  ]
}

locals {
  short_region = replace(var.region, "/^[^-]+-([^0-9-]+)[0-9]$/", "$1")
}

# Explicitly create each VPC as this will work on all supported Terraform versions

# Alpha - allows internet egress if the instance(s) have public IPs on nic0
module "alpha" {
  source                                 = "terraform-google-modules/network/google"
  version                                = "3.0.0"
  project_id                             = module.project.project_id
  network_name                           = "alpha"
  delete_default_internet_gateway_routes = false
  mtu                                    = 1500
  subnets = [
    {
      subnet_name           = format("alpha-%s", local.short_region)
      subnet_ip             = "172.16.0.0/16"
      subnet_region         = var.region
      subnet_private_access = false
    }
  ]
}

# Beta - a NAT gateway will be provisioned to support egress for control-plane
# download and installation of libraries, reaching Google APIs, etc.
module "beta" {
  source                                 = "terraform-google-modules/network/google"
  version                                = "3.0.0"
  project_id                             = module.project.project_id
  network_name                           = "beta"
  delete_default_internet_gateway_routes = false
  mtu                                    = 1500
  subnets = [
    {
      subnet_name           = format("beta-%s", local.short_region)
      subnet_ip             = "172.17.0.0/16"
      subnet_region         = var.region
      subnet_private_access = false
    }
  ]
}

# Gamma - default routes are deleted
module "gamma" {
  source                                 = "terraform-google-modules/network/google"
  version                                = "3.0.0"
  project_id                             = module.project.project_id
  network_name                           = "gamma"
  delete_default_internet_gateway_routes = true
  mtu                                    = 1500
  subnets = [
    {
      subnet_name           = format("gamma-%s", local.short_region)
      subnet_ip             = "172.18.0.0/16"
      subnet_region         = var.region
      subnet_private_access = false
    }
  ]
}

# Create a NAT gateway on the beta network - this allows the BIG-IP instances
# to download F5 libraries, use Secret Manager, etc, on management interface
# which is the only interface configured until DO is applied.
module "beta-nat" {
  source                             = "terraform-google-modules/cloud-nat/google"
  version                            = "~> 1.3.0"
  project_id                         = module.project.project_id
  region                             = var.region
  name                               = "vpc-controls-beta"
  router                             = "vpc-controls-beta"
  create_router                      = true
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  network                            = module.beta.network_self_link
  subnetworks = [
    {
      name                     = element(module.beta.subnets_self_links, 0)
      source_ip_ranges_to_nat  = ["ALL_IP_RANGES"]
      secondary_ip_range_names = []
    },
  ]
}

# Note: not using Google module to avoid dependency problems when creating from scratch.
# Create the service account to be used by Terraform, scoped to project
resource "google_service_account" "tf" {
  project      = module.project.project_id
  account_id   = "terraform"
  display_name = "Terraform automation service account"
}

# Bind the impersonation privileges to the Terraform service account if group
# list is not empty.
resource "google_service_account_iam_member" "tf_impersonate_user" {
  for_each           = toset(var.tf_sa_impersonators)
  service_account_id = google_service_account.tf.name
  role               = "roles/iam.serviceAccountUser"
  member             = each.value
}

resource "google_service_account_iam_member" "tf_impersonate_token" {
  for_each           = toset(var.tf_sa_impersonators)
  service_account_id = google_service_account.tf.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = each.value
}

resource "google_project_iam_member" "tf_sa_roles" {
  for_each = toset([
    "roles/compute.admin",
    "roles/iam.serviceAccountUser",
    "roles/secretmanager.admin",
  ])
  project = module.project.project_id
  role    = each.value
  member  = format("serviceAccount:%s", google_service_account.tf.email)
}

# Create a service account for BIG-IP instances
resource "google_service_account" "bigip" {
  project      = module.project.project_id
  account_id   = "big-ip"
  display_name = "BIG-IP instance service account"
}

resource "google_project_iam_member" "bigip_sa_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
  ])
  project = module.project.project_id
  role    = each.value
  member  = format("serviceAccount:%s", google_service_account.bigip.email)
}

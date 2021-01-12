# This module has been tested with Terraform 0.14 but is using modules that
# are supported in versions 0.13+.
terraform {
  required_version = "> 0.12"
}

# Service account impersonation (if enabled) and Google provider setup is
# handled in providers.tf

# Generate a random prefix
resource "random_pet" "prefix" {
  length = 1
  keepers = {
    project_id = var.project_id
  }
}

module "org_policy" {
  source      = "terraform-google-modules/vpc-service-controls/google"
  version     = "2.0.0"
  parent_id   = var.org_id
  policy_name = format("%s-vpc-bigip", random_pet.prefix.id)
}

module "service_perimeter_bigip" {
  source              = "terraform-google-modules/vpc-service-controls/google/modules/regular_service_perimeter"
  version             = "2.0.0"
  policy              = module.org_policy.policy_id
  perimeter_name      = format("%s-bigip", random_pet.prefix.id)
  description         = "Enforcing VPC service control policy for BIG-IP"
  resources           = [var.project_id]
  restricted_services = ["compute.googleapis.com"]
}

# Create the service account(s) to be used in the project
module "sa" {
  source     = "terraform-google-modules/service-accounts/google"
  version    = "3.0.1"
  project_id = var.project_id
  prefix     = random_pet.prefix.id
  names      = ["bigip"]
  project_roles = [
    "${var.project_id}=>roles/logging.logWriter",
    "${var.project_id}=>roles/monitoring.metricWriter",
    "${var.project_id}=>roles/monitoring.viewer",
  ]
  generate_keys = false
}

module "password" {
  source     = "memes/secret-manager/google//modules/random"
  version    = "1.0.2"
  project_id = var.project_id
  id         = format("%s-bigip-admin-key", random_pet.prefix.id)
  accessors = [
    # Generated service account email address is predictable - use it directly
    format("serviceAccount:%s-bigip@%s.iam.gserviceaccount.com", random_pet.prefix.id, var.project_id),
  ]
  length           = 16
  special_char_set = "@#%&*()-_=+[]<>:?"
}

locals {
  short_region = replace(var.region, "/^[^-]+-([^0-9-]+)[0-9]$/", "$1")
}

# Explicitly create each VPC as this will work on all supported Terraform versions

# Alpha - allows internet egress if the instance(s) have public IPs on nic0
module "alpha" {
  source                                 = "terraform-google-modules/network/google"
  version                                = "3.0.0"
  project_id                             = var.project_id
  network_name                           = format("%s-alpha", random_pet.prefix.id)
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
  project_id                             = var.project_id
  network_name                           = format("%s-beta", random_pet.prefix.id)
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
  project_id                             = var.project_id
  network_name                           = format("%s-gamma", random_pet.prefix.id)
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
  project_id                         = var.project_id
  region                             = var.region
  name                               = format("%s-beta", random_pet.prefix.id)
  router                             = format("%s-beta", random_pet.prefix.id)
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

# Randomise the zones to be used by modules
data "google_compute_zones" "available" {
  project = var.project_id
  region  = var.region
  status  = "UP"
}

resource "random_shuffle" "zones" {
  input = data.google_compute_zones.available.names
  keepers = {
    prefix = var.prefix
    region = var.region
  }
}

module "bigip" {
  source                            = "git::https://github.com/memes/terraform-google-f5-bigip"
  project_id                        = var.project_id
  zones                             = random_shuffle.zones.result
  num_instances                     = var.num_instances
  instance_name_template            = format("%s-vpc-%d", var.prefix)
  machine_type                      = "n1-standard-8"
  service_account                   = module.sa.emails["bigip"]
  enable_serial_console             = true
  external_subnetwork               = element(module.alpha.subnets_self_links, 0)
  provision_external_public_ip      = false
  management_subnetwork             = element(module.alpha.subnets_self_links, 0)
  internal_subnetworks              = module.alpha.subnets_self_links
  admin_password_secret_manager_key = module.password.secret_id
}

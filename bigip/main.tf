# This example is only supported on Terraform 0.13+ due to upstream module dependencies.
terraform {
  required_version = "~> 0.13"
}

# Service account impersonation (if enabled) and Google provider setup is
# handled in providers.tf

data "terraform_remote_state" "root" {
  backend = "local"
  config = {
    path = "../terraform.tfstate"
  }
}

# Generate a random prefix
resource "random_pet" "prefix" {
  length = 1
  keepers = {
    project_id = data.terraform_remote_state.root.outputs.project_id
  }
}

module "password" {
  source           = "memes/secret-manager/google//modules/random"
  version          = "1.0.2"
  project_id       = data.terraform_remote_state.root.outputs.project_id
  id               = format("%s-bigip-admin-key", random_pet.prefix.id)
  accessors        = formatlist("serviceAccount:%s", [data.terraform_remote_state.root.outputs.bigip_sa])
  length           = 16
  special_char_set = "@#%&*()-_=+[]<>:?"
}

# Randomise the zones to be used by modules
data "google_compute_zones" "available" {
  project = data.terraform_remote_state.root.outputs.project_id
  region  = data.terraform_remote_state.root.outputs.region
  status  = "UP"
}

resource "random_shuffle" "zones" {
  input = data.google_compute_zones.available.names
  keepers = {
    prefix = random_pet.prefix.id
    region = data.terraform_remote_state.root.outputs.region
  }
}

module "bigip" {
  source                            = "memes/f5-bigip/google"
  version                           = "2.1.0-rc1"
  project_id                        = data.terraform_remote_state.root.outputs.project_id
  zones                             = random_shuffle.zones.result
  num_instances                     = 1
  instance_name_template            = format("%s-vpc-%%d", random_pet.prefix.id)
  machine_type                      = "n1-standard-8"
  service_account                   = data.terraform_remote_state.root.outputs.bigip_sa
  enable_serial_console             = true
  external_subnetwork               = element(data.terraform_remote_state.root.outputs.subnets, 0)
  provision_external_public_ip      = false
  management_subnetwork             = length(data.terraform_remote_state.root.outputs.subnets) > 1 ? element(data.terraform_remote_state.root.outputs.subnets, 1) : null
  internal_subnetworks              = length(data.terraform_remote_state.root.outputs.subnets) > 2 ? slice(data.terraform_remote_state.root.outputs.subnets, 2, length(data.terraform_remote_state.root.outputs.subnets)) : null
  admin_password_secret_manager_key = module.password.secret_id
  image                             = "projects/f5-7626-networks-public/global/images/f5-bigip-15-1-2-0-0-9-payg-good-25mbps-201110225418"
}

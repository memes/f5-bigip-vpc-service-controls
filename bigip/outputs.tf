output "service_account" {
  value       = data.terraform_remote_state.root.outputs.bigip_sa
  description = <<EOD
The fully-qualified service account email to use with BIG-IP instances.
EOD
}

output "admin_password_secret_manager_key" {
  value       = module.password.secret_id
  description = <<EOD
The project-local secret id containing the generated BIG-IP admin password.
EOD
}

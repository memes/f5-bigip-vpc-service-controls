output "project_id" {
  value       = module.project.project_id
  description = <<EOD
The generated project identifier.
EOD
}

output "subnets" {
  value       = compact(concat(module.alpha.subnets_self_links, module.beta.subnets_self_links, module.gamma.subnets_self_links))
  description = <<EOD
The set of generated subnets to use with BIG-IP.
EOD
}

output "region" {
  value       = var.region
  description = <<EOD
The GCE region to use.
EOD
}

output "bigip_sa" {
  value       = google_service_account.bigip.email
  description = <<EOD
Service account to use for BIG-IP instances.
EOD
}

output "tf_sa" {
  value       = google_service_account.tf.email
  description = <<EOD
Service account to use for Terraform in project.
EOD
}

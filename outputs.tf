output "portal_url" {
  description = "Direccion del portal en AWS, a traves del ALB"
  value       = "http://${module.app.alb_dns_name}"
}

output "target_group_arn" {
  description = "ARN del target group del ALB"
  value       = module.app.target_group_arn
}

output "azure_portal_url" {
  description = "Direccion del portal en Azure, a traves del Load Balancer"
  value       = var.enable_azure ? module.app_azure[0].portal_url : null
}

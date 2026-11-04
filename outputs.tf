output "portal_url" {
  description = "Direccion del portal a traves del ALB"
  value       = "http://${module.app.alb_dns_name}"
}

output "target_group_arn" {
  description = "ARN del target group del ALB"
  value       = module.app.target_group_arn
}

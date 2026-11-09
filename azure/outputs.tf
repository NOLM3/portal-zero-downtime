output "azure_portal_url" {
  description = "Direccion del portal en Azure, a traves del Load Balancer"
  value       = module.app_azure.portal_url
}

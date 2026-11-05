output "portal_url" {
  description = "Direccion del portal a traves del balanceador de Azure"
  value       = "http://${azurerm_public_ip.lb.ip_address}"
}

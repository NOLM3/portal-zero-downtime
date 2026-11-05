locals {
  tags = {
    Project   = "portal-zero-downtime"
    ManagedBy = "terraform"
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.name}"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_subnet" "this" {
  name                 = "snet-${var.name}"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_cidr]
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-${var.name}-web"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  security_rule {
    name                       = "allow-http-in"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_public_ip" "lb" {
  name                = "pip-${var.name}-lb"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_lb" "this" {
  name                = "lb-${var.name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  tags                = local.tags

  frontend_ip_configuration {
    name                 = "frontend"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "this" {
  name            = "backend"
  loadbalancer_id = azurerm_lb.this.id
}

resource "azurerm_lb_probe" "http" {
  name                = "http-health"
  loadbalancer_id     = azurerm_lb.this.id
  protocol            = "Http"
  port                = 80
  request_path        = "/health"
  interval_in_seconds = 5
}

resource "azurerm_lb_rule" "http" {
  name                           = "http"
  loadbalancer_id                = azurerm_lb.this.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.this.id]
  probe_id                       = azurerm_lb_probe.http.id
}

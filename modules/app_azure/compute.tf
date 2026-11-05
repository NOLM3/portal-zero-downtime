resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_network_interface" "web" {
  count = var.instance_count

  name                = "nic-${var.name}-${count.index + 1}-${var.portal_version}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.this.id
    private_ip_address_allocation = "Dynamic"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "web" {
  count = var.instance_count

  network_interface_id    = azurerm_network_interface.web[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.this.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_linux_virtual_machine" "web" {
  count = var.instance_count

  name                  = "vm-${var.name}-${count.index + 1}-${var.portal_version}"
  computer_name         = "${var.name}-web-${count.index + 1}-${var.portal_version}"
  location              = azurerm_resource_group.this.location
  resource_group_name   = azurerm_resource_group.this.name
  size                  = var.vm_size
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.web[count.index].id]
  tags                  = merge(local.tags, { PortalVersion = var.portal_version })

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    portal_version = var.portal_version
  }))

  lifecycle {
    create_before_destroy = true
  }
}

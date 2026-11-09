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

  # La maquina se crea despues de quedar inscrita en el balanceador,
  # para que el gate de entrada pueda verla responder a traves de el.
  depends_on = [
    azurerm_network_interface_backend_address_pool_association.web,
    azurerm_lb_rule.http,
  ]

  lifecycle {
    create_before_destroy = true
  }

  # Gate de entrada: consultar el portal a traves del balanceador hasta
  # recibir la version nueva. Maximo 10 minutos (120 intentos de 5 s).
  provisioner "local-exec" {
    command = <<-EOT
      for i in $(seq 1 120); do
        v=$(curl -s -m 3 http://${azurerm_public_ip.lb.ip_address}/version)
        if [ "$v" = "${var.portal_version}" ]; then
          echo "Gate de entrada OK: el balanceador responde ${var.portal_version}"
          exit 0
        fi
        sleep 5
      done
      echo "Gate de entrada FALLIDO: ${var.portal_version} no respondio a tiempo"
      exit 1
    EOT
  }

  # Gate de salida: hacer fallar el health probe de la maquina vieja,
  # esperar a que el balanceador la saque y terminen sus visitas, y recien
  # ahi dejar que Terraform la borre.
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      az vm run-command invoke --resource-group ${self.resource_group_name} --name ${self.name} --command-id RunShellScript --scripts "rm -f /opt/portal/health" --output none
      sleep 30
    EOT
  }
}

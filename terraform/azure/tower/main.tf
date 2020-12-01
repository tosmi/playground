provider "azurerm" {
  # Whilst version is optional, we /strongly recommend/ using it to pin the version of the Provider being used
  version = "=2.38.0"
  features {}
}

# terraform {
#   required_providers {
#     ansible = {
#       source = "nbering/ansible"
#       version = "1.0.4"
#     }
#   }
# }

# provider "ansible" {
#   # Configuration options
# }

# NOT mangaged by terraform
#
resource "azurerm_resource_group" "tower-rg" {
  name     = "tower-rg"
  location = "eastus"

  tags = {
    environment = "Ansible Tower Demo"
  }
}

resource "azurerm_virtual_network" "tower-vnet" {
  name                = "tower-vnet"
  address_space       = ["10.0.0.0/24"]
  location            = "eastus"
  resource_group_name = azurerm_resource_group.tower-rg.name

  tags = {
    environment = "Ansible Tower Demo"
  }
}

resource "azurerm_subnet" "default" {
  name = "default"
  resource_group_name =  azurerm_resource_group.tower-rg.name
  virtual_network_name = azurerm_virtual_network.tower-vnet.name
  address_prefixes = ["10.0.0.0/24"]
}

resource "azurerm_public_ip" "publicip" {
    name                         = "tower-publicip"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.tower-rg.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Ansible Tower Demo"
    }
}

resource "azurerm_network_security_group" "tower-nsg" {
    name                = "tower-nsg"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.tower-rg.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Ansible Tower Demo"
    }
}

resource "azurerm_network_interface" "tower01-nic" {
  name = "tower01-nic"
  location = "eastus"
  resource_group_name = azurerm_resource_group.tower-rg.name

  ip_configuration {
    name = "ipconfig1"
    subnet_id = azurerm_subnet.default.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "tower" {
    network_interface_id      = azurerm_network_interface.tower01-nic.id
    network_security_group_id = azurerm_network_security_group.tower-nsg.id
}

# Create (and display) an SSH key
# resource "tls_private_key" "example_ssh" {
#   algorithm = "RSA"
#   rsa_bits = 4096
# }
# output "tls_private_key" { value = tls_private_key.example_ssh.private_key_pem }

resource "azurerm_linux_virtual_machine" "tower01" {
  name                  = "tower01"
  location              = "eastus"
  resource_group_name   = azurerm_resource_group.tower-rg.name
  network_interface_ids = [azurerm_network_interface.tower01-nic.id]
  size                  = "Standard_B1s"
  # for tower
  # size                  = "Standard_B2s"

  os_disk {
    name              = "tower01-disk"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "8"
    version   = "latest"
  }

  computer_name  = "tower01"
  admin_username = "rhadmin"
  disable_password_authentication = true

  admin_ssh_key {
    username       = "rhadmin"
    public_key     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDw3VG4B9wiSc1UR9igEGxSc66f1BvBVVX3h+e7drwTV5r0sv4hVqymk7UCQYiTsZZiqM2t3VSUyPcG7zi86sgmjpeuZxgXQWj1AiASoNyv4IK0z3PDZtedJJUrK6ztYwPhsIhUrlA6oLTtYJ+e5x78zjJwmIPwMfU0cGlUsRKU+cB0Dnuy9Au9Xq9ZJmiNuerwsAjaaXVaeETW7PAshGov5wxfqlQ7qH2IpMuEeoO5OM1PuRHFaWA+bnjI8HNm+Hv4ARnG9G+GUa5kXGsY6eHZNiarb1pKVMv9k53/iKe+3Y4jWD3q6vODyUiKCix3e72hBGhQuZbMybpY89HF7BJPa9QrIv3b8sb0/dYkrTa/8tFYP/XN6mDegwaVk8IG+1/bDPBIxx0PkYAKg82abGMlOwYGQMbaH7S6E+/yrl5fnM5EVU5LSoOM2OMFnWHmqJDk0bdoHpPI523pgBDmxVJHFMfhGSyEE40SZ/JCjwMOKu1wTtBVoXRiW5aTzpQ4apY8iMCHcm2AQ09P7aoFitK7CFmhUVMfIK6qcY0HWFx6Et6GxPH4K8MT1hnN1uU1R0hXVWIDs51UWT5/G1hxP6A3ogYkn3b0gUA/oTFFPFko7QX8h0qPfDhsw1dOs9k5S4zUkv4kNtZpue/EPvsplJQcwyRJvuq5hkXDvH7+nSJJqw== toni@stderr.at"
  }

  tags = {
    environment = "Ansible Tower Demo"
    dev = "true"
  }
}
resource "azurerm_postgresql_server" "tower-db" {
  name                = "tower-db"
  location            = azurerm_resource_group.tower-rg.location
  resource_group_name = azurerm_resource_group.tower-rg.name

  administrator_login          = "awx"
  administrator_login_password = "redhat"

  sku_name   = "GP_Gen5_2"
  version    = "10"
  storage_mb = 5120

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = false

  public_network_access_enabled    = false
  ssl_enforcement_enabled          = true
  ssl_minimal_tls_version_enforced = "TLS1_2"
}

resource "azurerm_postgresql_firewall_rule" "tower-pgrule" {
  name                = "office"
  resource_group_name = azurerm_resource_group.tower-rg.name
  server_name         = azurerm_postgresql_server.tower-db.name
  start_ip_address    = azurerm_public_ip.publicip.ip_address
  end_ip_address      = azurerm_public_ip.publicip.ip_address
}

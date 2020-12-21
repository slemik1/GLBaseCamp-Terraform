provider "azurerm" {
    features {}
}

resource "azurerm_resource_group" "azure_nginx_group" {
    name     = "myResourceGroup"
    location = "eastus"

    tags = {
        environment = "Terraform Demo"
    }
}

resource "azurerm_virtual_network" "azure_nginx_network" {
    name                = "myVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.azure_nginx_group.name

    tags = {
        environment = "Demo"
    }
}

resource "azurerm_subnet" "azure_nginx_subnet" {
    name                 = "mySubnet"
    resource_group_name  = azurerm_resource_group.azure_nginx_group.name
    virtual_network_name = azurerm_virtual_network.azure_nginx_network.name
    address_prefixes       = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "azure_nginx_public_ip" {
    name                         = "myPublicIP"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.azure_nginx_group.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Demo"
    }
}

resource "azurerm_network_security_group" "nginx_nsg" {
    name                = "nginx_security_group"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.azure_nginx_group.name

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
    security_rule {
        name                       = "HTTP"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Demo"
    }
}

resource "azurerm_network_interface" "nginx_nic" {
    name                      = "myNIC"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.azure_nginx_group.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.azure_nginx_subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.azure_nginx_public_ip.id
    }

    tags = {
        environment = "Demo"
    }
}

resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.nginx_nic.id
    network_security_group_id = azurerm_network_security_group.nginx_nsg.id
}

resource "random_id" "randomId" {
    keepers = {
        resource_group = azurerm_resource_group.azure_nginx_group.name
    }

    byte_length = 8
}

resource "azurerm_storage_account" "mystorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.azure_nginx_group.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Demo"
    }
}

resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { value = tls_private_key.example_ssh.private_key_pem }

resource "azurerm_linux_virtual_machine" "nginx-1" {
    name                  = "nginx-1"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.azure_nginx_group.name
    network_interface_ids = [azurerm_network_interface.nginx_nic.id]
    size                  = "Standard_DS1_v2"
    custom_data           = filebase64("./install.sh")

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "Nginx-1"
    admin_username = "azureuser"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "azureuser"
        public_key     = tls_private_key.example_ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "nginx-1"
    }
}

/*
resource "azurerm_linux_virtual_machine" "nginx-2" {
    name                  = "nginx-2"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.azure_nginx_group.name
    network_interface_ids = [azurerm_network_interface.nginx_nic.id]
    size                  = "Standard_DS1_v2"
    custom_data           = filebase64("./install.sh")

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "Nginx-2"
    admin_username = "azureuser"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "azureuser"
        public_key     = tls_private_key.example_ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "nginx-2"
    }
}
*/
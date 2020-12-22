provider "azurerm" {
    features {}
}

resource "azurerm_resource_group" "azure_nginx_group" {
 name     = "nginx"
 location = "West Europe"
}

resource "azurerm_virtual_network" "azure_nginx_network" {
 name                = "Vnet"
 address_space       = ["10.0.0.0/16"]
 location            = azurerm_resource_group.azure_nginx_group.location
 resource_group_name = azurerm_resource_group.azure_nginx_group.name
}

resource "azurerm_subnet" "azure_nginx_subnet" {
 name                 = "subnet"
 resource_group_name  = azurerm_resource_group.azure_nginx_group.name
 virtual_network_name = azurerm_virtual_network.azure_nginx_network.name
 address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "azure_nginx_public_ip" {
 name                         = "PublicIPAddress"
 location                     = azurerm_resource_group.azure_nginx_group.location
 resource_group_name          = azurerm_resource_group.azure_nginx_group.name
 allocation_method            = "Static"
}

resource "azurerm_lb" "azure_nginx_lb" {
 name                = "loadBalancer"
 location            = azurerm_resource_group.azure_nginx_group.location
 resource_group_name = azurerm_resource_group.azure_nginx_group.name

 frontend_ip_configuration {
   name                 = "PublicIPAddress"
   public_ip_address_id = azurerm_public_ip.azure_nginx_public_ip.id
 }
}

resource "azurerm_lb_backend_address_pool" "azure_nginx_backend_address_pool" {
 resource_group_name = azurerm_resource_group.azure_nginx_group.name
 loadbalancer_id     = azurerm_lb.azure_nginx_lb.id
 name                = "BackEndAddressPool"
}

resource "azurerm_lb_nat_pool" "azure_nginx_nat" {
  resource_group_name            = azurerm_resource_group.azure_nginx_group.name
  loadbalancer_id                = azurerm_lb.azure_nginx_lb.id
  name                           = "SampleApplicationPool"
  protocol                       = "Tcp"
  frontend_port_start            = 80
  frontend_port_end              = 81
  backend_port                   = 8080
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_network_interface" "nginx_nic" {
 count               = 2
 name                = "acctni${count.index}"
 location            = azurerm_resource_group.azure_nginx_group.location
 resource_group_name = azurerm_resource_group.azure_nginx_group.name

 ip_configuration {
   name                          = "testConfiguration"
   subnet_id                     = azurerm_subnet.azure_nginx_subnet.id
   private_ip_address_allocation = "dynamic"
 }
}

resource "azurerm_managed_disk" "nginx_disk" {
 count                = 2
 name                 = "datadisk_existing_${count.index}"
 location             = azurerm_resource_group.azure_nginx_group.location
 resource_group_name  = azurerm_resource_group.azure_nginx_group.name
 storage_account_type = "Standard_LRS"
 create_option        = "Empty"
 disk_size_gb         = "1023"
}

resource "azurerm_availability_set" "nginx_avset" {
 name                         = "avset"
 location                     = azurerm_resource_group.azure_nginx_group.location
 resource_group_name          = azurerm_resource_group.azure_nginx_group.name
 platform_fault_domain_count  = 2
 platform_update_domain_count = 2
 managed                      = true
}

resource "azurerm_virtual_machine" "nginx_vm" {
 count                 = 2
 name                  = "acctvm${count.index}"
 location              = azurerm_resource_group.azure_nginx_group.location
 availability_set_id   = azurerm_availability_set.nginx_avset.id
 resource_group_name   = azurerm_resource_group.azure_nginx_group.name
 network_interface_ids = [element(azurerm_network_interface.nginx_nic.*.id, count.index)]
 vm_size               = "Standard_DS1_v2"
 

 storage_image_reference {
   publisher = "Canonical"
   offer     = "UbuntuServer"
   sku       = "16.04-LTS"
   version   = "latest"
 }

 storage_os_disk {
   name              = "myosdisk${count.index}"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 # Optional data disks
 storage_data_disk {
   name              = "datadisk_new_${count.index}"
   managed_disk_type = "Standard_LRS"
   create_option     = "Empty"
   lun               = 0
   disk_size_gb      = "1023"
 }

 storage_data_disk {
   name            = element(azurerm_managed_disk.nginx_disk.*.name, count.index)
   managed_disk_id = element(azurerm_managed_disk.nginx_disk.*.id, count.index)
   create_option   = "Attach"
   lun             = 1
   disk_size_gb    = element(azurerm_managed_disk.nginx_disk.*.disk_size_gb, count.index)
 }

 os_profile {
   computer_name  = "hostname"
   admin_username = "azureuser"
   admin_password = "JZg-#9cH+S62Skp+gS86a+!5nV%&C62m"
   custom_data    = filebase64("./install.sh")
 }

 os_profile_linux_config {
   disable_password_authentication = false
 }

 tags = {
   environment = "staging"
 }
}

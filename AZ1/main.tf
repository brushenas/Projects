variable "prefix" {   default = "tf" }
variable "admin_username" { default ="plankton" }
variable "admin_password" { default ="Password1234" }

# Configure the Azure provider
provider "azurerm" {
    version = "~>1.35.0"
}

# Create a new resource group
resource "azurerm_resource_group" "rg" {
    name     = "${var.prefix}_RG"
    location = "westus"
    tags     = {Department="IT", costCenter="9200"}
}
# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
    name                = "tf_VNET"
    address_space       = ["10.0.0.0/16"]
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
}
# Create subnet
resource "azurerm_subnet" "subnet" {
  name                 = "tf_subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefix       = "10.0.1.0/24"
}

# Create public IP
resource "azurerm_public_ip" "publicip" {
  name                = "tf_publicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
  name                = "tf_NSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

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
}

# Create network interface
resource "azurerm_network_interface" "nic" {
  name                      = "tf_NIC"
  location                  = azurerm_resource_group.rg.location
  resource_group_name       = azurerm_resource_group.rg.name
  network_security_group_id = azurerm_network_security_group.nsg.id

  ip_configuration {
    name                          = "tf_nicConfg"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

# Create a Linux virtual machine
resource "azurerm_virtual_machine" "vm" {
  name                  = "tf_linux_VM"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  vm_size               = "Standard_DS1_v2"

  storage_os_disk {
    name              = "myOsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  os_profile {
    computer_name  = "tflinux"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
    provisioner "file" {
        connection {
            type     = "ssh"
            host     = azurerm_public_ip.publicip.ip_address
            user     = var.admin_username
            password = var.admin_password
        }

        source      = "newfile.txt"
        destination = "newfile.txt"
    }

    provisioner "remote-exec" {
        connection {
            type     = "ssh"
            host     = azurerm_public_ip.publicip.ip_address
            user     = var.admin_username
            password = var.admin_password
        }

        inline = [
        "ls -a",
        "cat newfile.txt"
        ]
    }
}



output "resource_group" {
  value = azurerm_resource_group.rg

}

output "ip_address" {
  value = azurerm_public_ip.publicip.ip_address
  
  
}
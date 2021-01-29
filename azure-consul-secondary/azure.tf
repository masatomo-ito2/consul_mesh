module "azure-app-network" {
  source              = "Azure/network/azurerm"
  resource_group_name = var.rg_name
  vnet_name           = "app-vnet"
  address_space       = "10.0.0.0/16"
  subnet_prefixes     = ["10.0.0.0/24"]
  subnet_names        = ["shared"]

  tags = {
    owner = "masa@hashicorp.com"
  }
}

resource "azurerm_public_ip" "consul" {
  name                = "consul-server-ip"
  resource_group_name = var.rg_name
  location            = var.rg_location
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "mgw" {
  name                = "consul-mgw-ip"
  resource_group_name = var.rg_name
  location            = var.rg_location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "consul" {
  name                = "consul-server-nic"
  resource_group_name = var.rg_name
  location            = var.rg_location

  ip_configuration {
    name                          = "config"
    subnet_id                     = module.azure-app-network.vnet_subnets[0]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.consul.id
  }

  tags = {
    Name = "consul"
    Env  = "consul-${var.env}"
  }

}

resource "azurerm_linux_virtual_machine" "consul" {
  name                  = "consul-server-vm"
  location              = var.rg_location
  resource_group_name   = var.rg_name
  network_interface_ids = [azurerm_network_interface.consul.id]
  size                  = "Standard_DS1_v2"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.azure_consul_user_assigned_identity_id]
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    name                 = "consul-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  computer_name = "consul-server-0"
  custom_data   = base64encode(data.template_file.azure-server-init.rendered)

  disable_password_authentication = true

  admin_username = "ubuntu"
  admin_ssh_key {
    username   = "ubuntu"
    public_key = var.ssh_public_key
  }

  tags = {
    Name = "consul"
    Env  = "consul-${var.env}"
  }

}

data "template_file" "azure-server-init" {
  template = file("${path.module}/scripts/azure_consul_server.sh")
  vars = {
    tpl_ca_cert             = "test"
    tpl_cert                = "test",
    tpl_key                 = "test",
    tpl_primary_wan_gateway = "${var.aws_mgw_public_ip}:443"
    tpl_vault_addr          = var.vault_addr
    tpl_namespace     = var.vault_namespace
    tpl_aws_region          = var.aws_region
    tpl_azure_region        = var.rg_name
  }
}

resource "azurerm_network_interface" "consul-mgw" {
  name                = "consul-mgw-nic"
  resource_group_name = var.rg_name
  location            = var.rg_location

  ip_configuration {
    name                          = "config"
    subnet_id                     = module.azure-app-network.vnet_subnets[0]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mgw.id
  }

  tags = {
    Name = "consul"
    Env  = "consul-${var.env}"
  }

}

data "template_file" "azure-mgw-init" {
  template = file("${path.module}/scripts/azure_mesh_gateway.sh")
  vars = {
    tpl_env             = var.env
    tpl_ca_cert         = "test"
    tpl_subscription_id = data.azurerm_subscription.primary.subscription_id
    tpl_vault_addr      = var.vault_addr
    tpl_vault_namespace = var.vault_namespace
    tpl_aws_region      = var.aws_region
    tpl_azure_region    = var.rg_name
  }
}

resource "azurerm_linux_virtual_machine" "consul-mgw" {
  name                  = "consul-mgw-vm"
  resource_group_name   = var.rg_name
  location              = var.rg_location
  network_interface_ids = [azurerm_network_interface.consul-mgw.id]
  size                  = "Standard_DS1_v2"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.azure_consul_user_assigned_identity_id]
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  os_disk {
    name                 = "consul-mgw-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  computer_name = "consul-mgw"
  custom_data   = base64encode(data.template_file.azure-mgw-init.rendered)

  admin_username = "ubuntu"

  admin_ssh_key {
    username   = "ubuntu"
    public_key = var.ssh_public_key
  }

  tags = {
    Name = "consul-mgw"
    Env  = "consul-${var.env}"
  }

}

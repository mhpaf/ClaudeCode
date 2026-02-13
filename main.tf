resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# --- 1. Networking ---
resource "azurerm_virtual_network" "vnet" {
  name                = "claude-foundry-vnet"
  address_space       = ["10.2.0.0/16"]
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "default"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.2.1.0/24"]
}

resource "azurerm_public_ip" "pip" {
  name                = "claude-vm-pip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "nsg" {
  name                = "claude-vm-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*" # BITTE auf deine IP einschränken!
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "claude-vm-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# --- 2. Identity & Permissions (Keyless Auth) ---
resource "azurerm_user_assigned_identity" "vm_identity" {
  location            = data.azurerm_resource_group.rg.location
  name                = "claude-vm-identity"
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Rolle: Azure AI Developer auf der RG (einfachheitshalber, besser auf Project scope)
resource "azurerm_role_assignment" "ai_developer" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Azure AI Developer"
  principal_id         = azurerm_user_assigned_identity.vm_identity.principal_id
}

# --- 3. Azure AI Foundry (Hub & Project) ---
# AI Services Account (Basis für den Hub)
resource "azurerm_cognitive_account" "aiservices" {
  name                = "claude-ai-services-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  kind                = "AIServices"
  sku_name            = "S0"
}

# AI Hub (via AzAPI, da azurerm_ai_studio_hub oft noch Preview ist)
resource "azapi_resource" "ai_hub" {
  type      = "Microsoft.MachineLearningServices/workspaces@2024-04-01-preview"
  name      = "claude-foundry-hub-${random_string.suffix.result}"
  location  = var.location
  parent_id = data.azurerm_resource_group.rg.id
  
  body = jsonencode({
    kind = "Hub"
    properties = {
      description = "Hub for Claude Code"
      friendlyName = "Claude Hub"
      hubResourceId = azurerm_cognitive_account.aiservices.id
    }
  })
}

# AI Project (Das eigentliche Ziel für Claude Code)
resource "azapi_resource" "ai_project" {
  type      = "Microsoft.MachineLearningServices/workspaces@2024-04-01-preview"
  name      = "claude-foundry-project"
  location  = var.location
  parent_id = data.azurerm_resource_group.rg.id
  
  body = jsonencode({
    kind = "Project"
    properties = {
      description = "Project for Claude Code CLI"
      friendlyName = "Claude Project"
      hubResourceId = azapi_resource.ai_hub.id
    }
  })
}

# --- 4. VM & SSH ---
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "pem" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/claude_key.pem"
  file_permission = "0600"
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "claude-dev-box"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_B2ms" # 2 vCPU, 8GB RAM (gut für Dev)
  admin_username      = var.vm_admin_username
  
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_SSD_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-noble"
    sku       = "24_04-lts"
    version   = "latest"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.vm_identity.id]
  }

  custom_data = data.cloudinit_config.config.rendered
}

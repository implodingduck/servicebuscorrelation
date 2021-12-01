terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.64.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
  }
  backend "azurerm" {

  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

locals {
  loc_for_naming = lower(replace(var.location, " ", ""))
}

data "azurerm_client_config" "current" {}

data "azurerm_log_analytics_workspace" "default" {
  name                = "DefaultWorkspace-${data.azurerm_client_config.current.subscription_id}-EUS"
  resource_group_name = "DefaultResourceGroup-EUS"
} 

resource azurerm_resource_group "rg" {
    name = "rg-servicebus-correlation-demo-${local.loc_for_naming}"
    location = var.location
}

resource "azurerm_servicebus_namespace" "correlation" {
  name                = "correlation-servicebus-namespace"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Basic"
}

resource "azurerm_servicebus_queue" "correlation" {
  name                = "correlation_servicebus_topic"
  resource_group_name = azurerm_resource_group.rg.name
  namespace_name      = azurerm_servicebus_namespace.correlation.name

  enable_partitioning = true
}


resource "null_resource" "build_typescript"{
  triggers = {
    index = "${timestamp()}"
  }
  provisioner "local-exec" {
    working_dir = "../func1"
    command     = "npm install && npm run build:production"
  }
}

resource "null_resource" "build_typescript2"{
  triggers = {
    index = "${timestamp()}"
  }
  provisioner "local-exec" {
    working_dir = "../func2"
    command     = "npm install && npm run build:production"
  }
}


module "func1" {
    depends_on = [
      null_resource.build_typescript
    ]
    source   = "github.com/implodingduck/tfmodules//functionapp"
    func_name = "correlationfunc1"
    resource_group_name = azurerm_resource_group.rg.name
    resource_group_location = azurerm_resource_group.rg.location
    working_dir = "../func1"
    app_settings = {
      "FUNCTIONS_WORKER_RUNTIME" = "node"
      "servicebusconnectstring"  = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.servicebusconnectstring.name})"
    }
    linux_fx_version = "node|14"
    identity = [{ 
      type = "System"
    }]
}

module "func2" {
    source   = "github.com/implodingduck/tfmodules//functionapp"
    func_name = "correlationfunc2"
    resource_group_name = azurerm_resource_group.rg.name
    resource_group_location = azurerm_resource_group.rg.location
    working_dir = "../func2"
    app_settings = {
      "FUNCTIONS_WORKER_RUNTIME" = "node"
      "servicebusconnectstring"  = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.servicebusconnectstring.name})"
    }
    linux_fx_version = "node|14"

    identity = [{ 
      type = "System"
    }]
}

resource "azurerm_key_vault" "kv" {
  name                       = "${local.func_name}-kv"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled = false


    
  tags = local.tags
}

resource "azurerm_key_vault_access_policy" "client-config" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = data.azurerm_client_config.current.object_id

  key_permissions = [
    "create",
    "get",
    "purge",
    "recover",
    "delete"
  ]

  secret_permissions = [
    "set",
    "purge",
    "get",
    "list",
    "delete"
  ]

  certificate_permissions = [
    "purge"
  ]

  storage_permissions = [
    "purge"
  ]
}

resource "azurerm_key_vault_access_policy" "func1" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = module.func1.identity_principal_id
  secret_permissions = [
    "get",
    "list"
  ]
}

resource "azurerm_key_vault_access_policy" "func2" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = module.func2.identity_principal_id
  secret_permissions = [
    "get",
    "list"
  ]
}
resource "azurerm_key_vault_secret" "servicebusconnectstring" {
  depends_on = [
    azurerm_key_vault_access_policy.client-config
  ]
  name         = "servicebusconnectstring"
  value        = azurerm_servicebus_namespace.correlation.default_primary_connection_string
  key_vault_id = azurerm_key_vault.kv.id
}
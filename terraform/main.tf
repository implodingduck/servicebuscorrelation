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
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

locals {
  loc_for_naming = lower(replace(var.location, " ", ""))
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
    working_dir = "func1"
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
      "servicebusconnectstring"  = azurerm_servicebus_namespace.correlation.default_primary_connection_string
    }
    linux_fx_version = "node|14"
}

module "func2" {
    source   = "github.com/implodingduck/tfmodules//functionapp"
    func_name = "correlationfunc2"
    resource_group_name = azurerm_resource_group.rg.name
    resource_group_location = azurerm_resource_group.rg.location
    working_dir = "../func2"
    app_settings = {
      "FUNCTIONS_WORKER_RUNTIME" = "node"
      "servicebusconnectstring"  = azurerm_servicebus_namespace.correlation.default_primary_connection_string
    }
    linux_fx_version = "node|14"
}
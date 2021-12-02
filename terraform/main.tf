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

resource "azurerm_user_assigned_identity" "sb" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  name = "uai-correlation-servicebus"
}

resource "azurerm_template_deployment" "sbnamespace" {
  name                = "sbnamespace-01"
  resource_group_name = azurerm_resource_group.rg.name

  template_body = <<DEPLOY
{
   "$schema":"https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
   "contentVersion":"1.0.0.0",
   "parameters":{
      "namespaceName":{
         "type":"string",
         "metadata":{
            "description":"Name for the Namespace."
         }
      },
      "location":{
         "type":"string",
         "defaultValue":"[resourceGroup().location]",
         "metadata":{
            "description":"Specifies the Azure location for all resources."
         }
      },
      "keyVaultUri":{
        "type":"string",
        "metadata":{
          "description":"URI of the KeyVault."
        }
      },
      "keyName":{
        "type":"string",
        "metadata":{
          "description":"KeyName."
        }
      },
      "userAssignedIdentity": {
        "type": "string",
        "metadata": {
            "description": "user-assigned identity."
        }
      }
   },
   "resources":[
      {
         "type":"Microsoft.ServiceBus/namespaces",
         "apiVersion":"2018-01-01-preview",
         "name":"[parameters('namespaceName')]",
         "location":"[parameters('location')]",
         "identity":{
            "type": "UserAssigned",
            "userAssignedIdentities": {
              "[parameters('userAssignedIdentity')]": {}
            }
         },
         "sku":{
            "name":"Premium",
            "tier":"Premium",
            "capacity":1
         },
         "properties":{
            "encryption":{
               "requireInfrastructureEncryption":true,  
               "keySource":"Microsoft.KeyVault",
               "keyVaultProperties":[
                    {
                        "keyName": "[parameters('keyName')]",
                        "keyVaultUri": "[parameters('keyVaultUri')]",
                        "identity": {
                            "userAssignedIdentity": "[parameters('identity').userAssignedIdentity]"
                        }
                    }
               ]
            }
         }
      }
   ],
   "outputs":{
      "ServiceBusNamespaceId":{
         "type":"string",
         "value":"[resourceId('Microsoft.ServiceBus/namespaces',parameters('namespaceName'))]"
      },
      "serviceBusEndpoint": {
        "type":"string",
        "value": "[reference(resourceId('Microsoft.ServiceBus/namespaces',parameters('namespaceName'))).serviceBusEndpoint]"
      },
      "allTheThings": {
        "type": "object",
        "value": "[reference(resourceId('Microsoft.ServiceBus/namespaces',parameters('namespaceName')))]"
      }
   }
}
DEPLOY
  parameters = {
    namespaceName = "correlation-servicebus-namespace"
    location = azurerm_resource_group.rg.location
    keyName = azurerm_key_vault_key.generated.name
    keyVaultUri = azurerm_key_vault.kv.vault_uri
    userAssignedIdentity = azurerm_user_assigned_identity.sb.id
  }

  deployment_mode = "Incremental"
}

# resource "azurerm_template_deployment" "sbencryption" {
#   depends_on = [
#     azurerm_template_deployment.sbnamespace,

#   ]
#   name                = "sbencryption-01"
#   resource_group_name = azurerm_resource_group.rg.name

#   template_body = <<DEPLOY
# {
#    "$schema":"https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
#    "contentVersion":"1.0.0.0",
#    "parameters":{
#       "namespaceName":{
#          "type":"string",
#          "metadata":{
#             "description":"Name for the Namespace to be created in cluster."
#          }
#       },
#       "location":{
#          "type":"string",
#          "defaultValue":"[resourceGroup().location]",
#          "metadata":{
#             "description":"Specifies the Azure location for all resources."
#          }
#       },
#       "keyVaultUri":{
#          "type":"string",
#          "metadata":{
#             "description":"URI of the KeyVault."
#          }
#       },
#       "keyName":{
#          "type":"string",
#          "metadata":{
#             "description":"KeyName."
#          }
#       }
#    },
#    "resources":[
#       {
#          "type":"Microsoft.ServiceBus/namespaces",
#          "apiVersion":"2018-01-01-preview",
#          "name":"[parameters('namespaceName')]",
#          "location":"[parameters('location')]",
#          "identity":{
#             "type":"SystemAssigned"
#          },
#          "sku":{
#             "name":"Premium",
#             "tier":"Premium",
#             "capacity":1
#          },
#          "properties":{
#             "encryption":{
#                "keySource":"Microsoft.KeyVault",
#                "keyVaultProperties":[
#                   {
#                      "keyName":"[parameters('keyName')]",
#                      "keyVaultUri":"[parameters('keyVaultUri')]"
#                   }
#                ]
#             }
#          }
#       }
#    ]
# }
# DEPLOY
#   parameters = {
#     namespaceName = "correlation-servicebus-namespace"
#     location = azurerm_resource_group.rg.location
#     keyName = 
#     keyVaultUri = 
#   }

#   deployment_mode = "Incremental"
# }


# resource "azurerm_servicebus_queue" "correlation" {
#   depends_on = [
#     azurerm_template_deployment.sbnamespace,
#     azurerm_template_deployment.sbencryption
#   ]
#   name                = "correlation_servicebus_topic"
#   resource_group_name = azurerm_resource_group.rg.name
#   namespace_name      = azurerm_servicebus_namespace.correlation.name

#   enable_partitioning = true
# }


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
    command     = "npm install"
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
      "servicebusconnectstring__fullyQualifiedNamespace"  = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.servicebusconnectstring.name})"
    }
    linux_fx_version = "node|14"
    app_identity = [{ 
      type = "SystemAssigned"
      identity_ids = null
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
      "servicebusconnectstring__fullyQualifiedNamespace"  = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.servicebusconnectstring.name})"
    }
    linux_fx_version = "node|14"

    app_identity = [{ 
      type = "SystemAssigned",
      identity_ids = null
    }]
}

resource "azurerm_key_vault" "kv" {
  name                       = "srvbus456456-kv"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled = false
  tags = {}
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
    "delete",
    "list",
    "decrypt",
    "encrypt",
    "unwrapKey",
    "wrapKey",
    "verify",
    "sign"
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

resource "azurerm_key_vault_access_policy" "sb" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = azurerm_user_assigned_identity.sb.principal_id

  key_permissions = [
    "get",
    "wrapKey",
    "unwrapKey",
    "list"
  ]

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
  value        = lookup(azurerm_template_deployment.sbnamespace.outputs, "serviceBusEndpoint", "TBD") #azurerm_servicebus_namespace.correlation.default_primary_connection_string
  key_vault_id = azurerm_key_vault.kv.id
}


resource "azurerm_key_vault_key" "generated" {
  name         = "generated-certificate"
  key_vault_id = azurerm_key_vault.kv.id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
}

resource "azurerm_role_assignment" "sender" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = module.func1.identity_principal_id
}

resource "azurerm_role_assignment" "receiver" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Azure Service Bus Data Receiver:"
  principal_id         = module.func1.identity_principal_id
}
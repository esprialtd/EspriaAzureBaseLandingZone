// modules/shared/azureFiles.bicep

@description('Azure region')
param region string

@description('Storage account name (must be globally unique)')
param storageAccountName string

@description('Share name for Azure Files')
param fileShareName string = 'sharedfiles'

@description('SKU for the storage account')
param skuName string = 'Premium_ZRS'

@description('Virtual Network ID for the private endpoint')
param vnetId string

@description('Name of the subnet for the private endpoint')
param privateEndpointSubnetName string = 'PrivateEndpoint'

@description('Resource group for private DNS zones')
param dnsZoneResourceGroup string

@description('vnet Name')
param vnetName string = 'vnet-${environment}-sharedservices-${customerAbbreviation}-${region}-01'

@description('Subnet Name')
param subnetName string = 'SharedServices'

@description('Core Subscription ID')
param coreSubscriptionId string

@description('Shared Subscription ID')
param sharedSubscriptionId string

@description('CreatedBy tag value')
param createdBy string

@description('ManagedBy tag value')
param managedBy string

@description('Location tag value')
param tagLocation string




resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: region
  sku: {
    name: skuName
  }
  kind: 'FileStorage'
  properties: {
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  name: '${storageAccount.name}/default/${fileShareName}'
  properties: {
    shareQuota: 100
    enabledProtocols: 'SMB'
  }
  dependsOn: [storageAccount]
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-02-01' = {
  name: '${storageAccountName}-pe'
  location: region
  properties: {
    subnet: {
      id: '${vnetId}/subnets/${privateEndpointSubnetName}'
    }
    privateLinkServiceConnections: [
      {
        name: 'fileStorageConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['file']
        }
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.file.core.windows.net'
  location: 'global'
}

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-06-01' = {
  name: 'default'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'file'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

output fileShareId string = fileShare.id

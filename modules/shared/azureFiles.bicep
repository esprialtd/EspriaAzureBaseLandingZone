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

@description('CreatedBy tag value')
param createdBy string

@description('ManagedBy tag value')
param managedBy string

@description('Location tag value')
param tagLocation string

@description('Application tag')
param applicationTag string = 'Connectivity and Routing'

@description('Function tag') 
param functionTag string = 'Core Management'

@description('Cost Center tag')
param costCenterTag string = 'Core Services'

@description('Environment tag')
param environment string


resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: region
  tags: {
    Application: applicationTag
    Function: functionTag
    CostCenter: costCenterTag
    CreatedBy: createdBy
    ManagedBy: managedBy
    Environment: environment
    Location: tagLocation
  }
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
output azureFilesId string = storageAccount.id

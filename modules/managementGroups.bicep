@description('Customer name (e.g., Espria)')
param customerName string

@description('Top-level management group ID')
param topLevelGroupId string = toLower(replace('${customerName}-Internal', ' ', '-'))

@description('Core services management group ID')
param coreGroupId string = toLower(replace('${customerName}-Core-Services', ' ', '-'))

@description('Shared services management group ID')
param sharedGroupId string = toLower(replace('${customerName}-Shared-Services', ' ', '-'))



// Set the target scope to tenant for management group creation

targetScope = 'tenant'

// Top-level: "Espria - Internal"
resource internalItMgmtGroup 'Microsoft.Management/managementGroups@2020-05-01' = {
  name: topLevelGroupId
  properties: {
    displayName: '${customerName} - Internal'
  }
}

// Core Services: "Espria - Internal - Core Services"
resource coreServicesMgmtGroup 'Microsoft.Management/managementGroups@2020-05-01' = {
  name: coreGroupId
  parent: internalItMgmtGroup
  properties: {
    displayName: '${customerName} - Internal - Core Services'
  }
}

// Shared Services: "Espria - Internal - Shared Services"
resource sharedServicesMgmtGroup 'Microsoft.Management/managementGroups@2020-05-01' = {
  name: sharedGroupId
  scope: 'internalItMgmtGroup'
  properties: {
    displayName: '${customerName} - Internal - Shared Services'
  }
}

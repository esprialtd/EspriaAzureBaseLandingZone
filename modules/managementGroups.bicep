@description('Customer name (e.g., Espria)')
param customerName string

@description('Top-level management group ID')
param topLevelGroupId string = toLower(replace('${customerName}-Internal', ' ', '-'))

@description('Core services management group ID')
param coreGroupId string = toLower(replace('${customerName}-Core-Services', ' ', '-'))

@description('Shared services management group ID')
param sharedGroupId string = toLower(replace('${customerName}-Shared-Services', ' ', '-'))

@description('Customer abbreviation (e.g., ESP)')
param customerAbbreviation string

@description('Top-level management group name')
param topLevelGroupName string = '${customerAbbreviation} - Internal'

@description('Core services management group name')
param coreServicesGroupName string = '${customerAbbreviation} - Internal - Core Services'

@description('Shared services management group name')
param sharedServicesGroupName string = '${customerAbbreviation} - Internal - Shared Services'

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
  properties: {
    displayName: '${customerName} - Internal - Core Services'
    parent: {
      id: internalItMgmtGroup.id
    }
  }
  dependsOn: [
    internalItMgmtGroup
  ]
}

// Shared Services: "Espria - Internal - Shared Services"
resource sharedServicesMgmtGroup 'Microsoft.Management/managementGroups@2020-05-01' = {
  name: sharedGroupId
  properties: {
    displayName: '${customerName} - Internal - Shared Services'
    parent: {
      id: internalItMgmtGroup.id
    }
  }
  dependsOn: [
    internalItMgmtGroup
  ]
}

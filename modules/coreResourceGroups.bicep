@description('Azure region')
param location string

@description('Environment tag value')
param environment string

@description('Customer abbreviation')
param customerAbbreviation string

@description('Region short name')
param region string

@description('Core services subscription ID')
param coreSubscriptionId string

targetScope = 'subscription'

// Core Resource Groups
resource rgCoreConnectivity 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environment}-core-connectivity-${customerAbbreviation}-${region}-01'
  scope: subscription(coreSubscriptionId)
  location: location
}

resource rgCoreIdentity 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environment}-core-identity-${customerAbbreviation}-${region}-01'
  scope: subscription(coreSubscriptionId)
  location: location
}

resource rgCoreManagement 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environment}-core-management-${customerAbbreviation}-${region}-01'
  scope: subscription(coreSubscriptionId)
  location: location
}


output rgCoreConnectivity string = rgCoreConnectivity.name
output rgCoreIdentity string = rgCoreIdentity.name
output rgCoreManagement string = rgCoreManagement.name

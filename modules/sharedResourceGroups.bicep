@description('Azure region')
param location string

@description('Environment tag value')
param environment string

@description('Customer abbreviation')
param customerAbbreviation string

@description('Region short name')
param region string
@description('Shared services subscription ID')
param sharedSubscriptionId string


targetScope = 'subscription'

// Shared Resource Group
resource rgSharedServices 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environment}-sharedservices-${customerAbbreviation}-${region}-01'
  scope: subscription(sharedSubscriptionId)
  location: location
}


output rgSharedServices string = rgSharedServices.name

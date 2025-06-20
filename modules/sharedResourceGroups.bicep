@description('Azure region')
param location string

@description('Environment tag value')
param environment string

@description('Customer abbreviation')
param customerAbbreviation string

@description('Region short name')
param region string

@description('Cost Center tag')
param costCenterTag string = 'Core Services'

@description('CreatedBy tag value')
param createdBy string

@description('ManagedBy tag value')
param managedBy string

@description('Location tag value')
param tagLocation string

targetScope = 'subscription'

// Shared Resource Group
resource rgSharedServices 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environment}-sharedservices-${customerAbbreviation}-${region}-01'
  location: location
  tags: {
    Application: 'Shared Services'
    Function: 'Shared Services'
    CostCenter: costCenterTag
    CreatedBy: createdBy
    ManagedBy: managedBy
    Environment: environment
    Location: tagLocation
  }
}


output rgSharedServices string = rgSharedServices.name

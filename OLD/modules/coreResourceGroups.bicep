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

// Core Resource Groups
resource rgCoreConnectivity 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environment}-core-connectivity-${customerAbbreviation}-${region}-01'
  location: location
  tags: {
    Application: 'Routing and Connectivity'
    Function: 'Core Connectivity'
    CostCenter: costCenterTag
    CreatedBy: createdBy
    ManagedBy: managedBy
    Environment: environment
    Location: tagLocation
  }
}

resource rgCoreIdentity 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environment}-core-identity-${customerAbbreviation}-${region}-01'
  location: location
  tags: {
    Application: 'Identity and Access Management'
    Function: 'Core Identity'
    CostCenter: costCenterTag
    CreatedBy: createdBy
    ManagedBy: managedBy
    Environment: environment
    Location: tagLocation
  }
}

resource rgCoreManagement 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environment}-core-management-${customerAbbreviation}-${region}-01'
  location: location
  tags: {
    Application: 'Management and Monitoring'
    Function: 'Core Management'
    CostCenter: costCenterTag
    CreatedBy: createdBy
    ManagedBy: managedBy
    Environment: environment
    Location: tagLocation
  }
}


output rgCoreConnectivity string = rgCoreConnectivity.name
output rgCoreIdentity string = rgCoreIdentity.name
output rgCoreManagement string = rgCoreManagement.name

// =============================================================================
// modules/governance/resourceGroups.bicep
// Creates all Core Services resource groups for a given region
// Scope: subscription
// =============================================================================

targetScope = 'subscription'

param location string
param customerAbbreviation string
param region string
param environment string
param tags object

var custAbbr = toUpper(customerAbbreviation)

resource rgConnectivity 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environment}-core-connectivity-${custAbbr}-${region}-01'
  location: location
  tags: union(tags, { Function: 'Connectivity' })
}

resource rgIdentity 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environment}-core-identity-${custAbbr}-${region}-01'
  location: location
  tags: union(tags, { Function: 'Identity' })
}

resource rgManagement 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environment}-core-management-${custAbbr}-${region}-01'
  location: location
  tags: union(tags, { Function: 'Management' })
}

output rgConnectivityName string = rgConnectivity.name
output rgIdentityName     string = rgIdentity.name
output rgManagementName   string = rgManagement.name

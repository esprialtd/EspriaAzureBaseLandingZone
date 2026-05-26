// modules/connectivity/connectivityCoreConnectivity.bicep
@description('Azure region')
param region string

@description('Environment')
param environment string

@description('Whether to associate NSGs')
param associateNSGs bool = true

@description('VNet address prefix')
param addressPrefix string

@description('Customer abbreviation')
param customerAbbreviation string

@description('VNet name')
param vnetName string

@description('Subnet configurations')
param subnetConfig array

@description('CreatedBy tag value')
param createdBy string

@description('ManagedBy tag value')
param managedBy string

@description('Location tag value')
param tagLocation string = 'UK South'

@description('Application tag')
param applicationTag string = 'Connectivity and Routing'

@description('Function tag') 
param functionTag string = 'Core Management'

@description('Cost Center tag')
param costCenterTag string = 'Core Services'

@description('List of subnet names NOT to associate NSGs to')
param excludeFromNsg array = []

var location = region

// 1. Create the VNet and subnets (only address prefixes and route tables)
resource vnet 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name:     vnetName
  location: resourceGroup().location
  tags: {
    Application: applicationTag
    Function:    functionTag
    CostCenter:  costCenterTag
    CreatedBy:   createdBy
    ManagedBy:   managedBy
    Environment: environment
    Location:    tagLocation
  }
  properties: {
    addressSpace: {
      addressPrefixes: [ addressPrefix ]
    }
    subnets: [
      {
        name: 'GatewaySubnet'
        properties: { addressPrefix: '10.101.0.0/26' }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: { addressPrefix: '10.101.0.64/26' }
      }
      {
        name: 'CoreServices'
        properties: { addressPrefix: '10.101.2.0/24' }
      }
      {
        name: 'PrivateEndpoint'
        properties: { addressPrefix: '10.101.7.0/24' }
      }
    ]
  }
}


// 2. Create NSGs for filtered subnets
resource nsgCollection 'Microsoft.Network/networkSecurityGroups@2023-02-01' = [
  for sn in subnetConfig: if (associateNSGs && !contains(excludeFromNsg, sn.name)) {
  name: 'nsg-${sn.name}-${vnetName}'
  location: location
  tags: {
    Application: applicationTag
    Function:    functionTag
    CostCenter:  costCenterTag
    CreatedBy:   createdBy
    ManagedBy:   managedBy
    Environment: environment
    Location:    tagLocation
  }
  properties: {}
}]

// 3. Associate NSGs to subnets via child resource, ensuring subnets & NSGs exist first
resource subnetNsgAssoc 'Microsoft.Network/virtualNetworks/subnets@2023-02-01' = [
  for sn in subnetConfig: if (associateNSGs && !contains(excludeFromNsg, sn.name)) {
    parent: vnet
    name: sn.name
    properties: {
      // Re-specify address prefix to avoid wiping it out
      addressPrefix: sn.addressPrefix
      networkSecurityGroup: {
        id: resourceId('Microsoft.Network/networkSecurityGroups', 'nsg-${sn.name}-${vnetName}')
      }
    }
    dependsOn: [ vnet, nsgCollection ]
  }
]



output vnetId string = vnet.id
output subnetIds object = {
  GatewaySubnet: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'GatewaySubnet')
  AzureFirewallSubnet: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureFirewallSubnet')
}

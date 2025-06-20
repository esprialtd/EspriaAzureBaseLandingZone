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

resource vnet 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  name: vnetName
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
  properties: {
    addressSpace: {
      addressPrefixes: [addressPrefix]
    }
    subnets: [for subnet in subnetConfig: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        }
        networkSecurityGroup: associateNSGs ? {
          id: resourceId('Microsoft.Network/networkSecurityGroups', 'nsg-${subnet.name}-vnet-${environment}-core-management-${customerAbbreviation}-${region}')
        } : null
      }
    ]
  }
}

// NSG creation
resource nsgs 'Microsoft.Network/networkSecurityGroups@2023-02-01' = [for subnet in subnetConfig: {
  name: 'nsg-${vnetName}-${subnet.name}'
  location: region
  properties: {}
}
]


output vnetId string = vnet.id
output subnetIds object = {
  GatewaySubnet: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'GatewaySubnet')
  AzureFirewallSubnet: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureFirewallSubnet')
}

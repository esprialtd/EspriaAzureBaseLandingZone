// modules/connectivity/connectivityCoreConnectivity.bicep

@description('Customer abbreviation')
param customerAbbreviation string

@description('Azure region')
param region string

@description('Environment')
param environment string

@description('VNet address prefix')
param addressPrefix string

@description('VNet name')
param vnetName string

@description('Should NSGs be associated to subnets?')
param associateNSGs string

@description('Subnet configurations')
param subnetConfig array

@description('Attach Route Tables to Subnets?')
param attachRouteTable string

@description('CreatedBy tag value')
param createdBy string

@description('ManagedBy tag value')
param managedBy string

@description('Location tag value')
param tagLocation string = 'UK South'

resource vnet 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  name: vnetName
  location: region
  properties: {
    addressSpace: {
      addressPrefixes: [addressPrefix]
    }
    subnets: [for subnet in subnetConfig: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        }
      }
    ]
  }
}

// Optional NSG creation if requested
resource nsgs 'Microsoft.Network/networkSecurityGroups@2023-02-01' = [for subnet in subnetConfig: if (associateNSGs) {
  name: 'nsg-${vnetName}-${subnet.name}'
  location: region
  properties: {}
}]

output vnetId string = vnet.id

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
param associateNSGs bool = true

@description('Subnet configurations')
param subnetConfig array

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
        networkSecurityGroup: empty(associateNSGs) ? null : {
          id: resourceId('Microsoft.Network/networkSecurityGroups', 'nsg-${vnetName}-${subnet.name}')
        }
      }
    }]
  }
}

// Optional NSG creation if requested
resource nsgs 'Microsoft.Network/networkSecurityGroups@2023-02-01' = [for subnet in subnetConfig: if (associateNSGs) {
  name: 'nsg-${vnetName}-${subnet.name}'
  location: region
  properties: {}
}]

output vnetId string = vnet.id
output azureFirewallPrivateIp string = azFirewall.properties.ipConfigurations[0].properties.privateIPAddress

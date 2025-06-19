// modules/connectivity/vNetGateway.bicep

@description('Customer abbreviation')
param customerAbbreviation string

@description('Azure region')
param region string

@description('Deployment environment')
param environment string

@description('CreatedBy tag')
param createdBy string

@description('ManagedBy tag')
param managedBy string

@description('Location tag')
param tagLocation string

@description('Virtual Network name')
param vnetName string

@description('GatewaySubnet ID')
param gatewaySubnetId string

@description('Public IP name for VNet Gateway')
param publicIpName string = 'pip-vnet-gw-${environment}-core-${customerAbbreviation}-${region}'

@description('Virtual Network Gateway name')
param gatewayName string = 'vnet-gw-${environment}-core-${customerAbbreviation}-${region}-01'

resource publicIp1 'Microsoft.Network/publicIPAddresses@2023-02-01' = {
  name: '${publicIpName}-01'
  location: region
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  tags: {
    CreatedBy: createdBy
    ManagedBy: managedBy
    Location: tagLocation
    Environment: environment
    Application: 'Connectivity and Routing'
    Function: 'Gateway'
    CostCenter: 'Core Services'
  }
}

resource publicIp2 'Microsoft.Network/publicIPAddresses@2023-02-01' = {
  name: '${publicIpName}-02'
  location: region
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  tags: {
    CreatedBy: createdBy
    ManagedBy: managedBy
    Location: tagLocation
    Environment: environment
    Application: 'Connectivity and Routing'
    Function: 'Gateway'
    CostCenter: 'Core Services'
  }
}

resource virtualNetworkGateway 'Microsoft.Network/virtualNetworkGateways@2023-02-01' = {
  name: gatewayName
  location: region
  dependsOn: [publicIp1, publicIp2]
  tags: {
    CreatedBy: createdBy
    ManagedBy: managedBy
    Location: tagLocation
    Environment: environment
    Application: 'Connectivity and Routing'
    Function: 'Gateway'
    CostCenter: 'Core Services'
  }
  properties: {
    enableBgp: false
    activeActive: true
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    sku: {
      name: 'VpnGw2AZ'
      tier: 'VpnGw2AZ'
    }
    ipConfigurations: [
      {
        name: 'gw-ipconfig1'
        properties: {
          subnet: {
            id: gatewaySubnetId
          }
          publicIPAddress: {
            id: publicIp1.id
          }
        }
      }
      {
        name: 'gw-ipconfig2'
        properties: {
          subnet: {
            id: gatewaySubnetId
          }
          publicIPAddress: {
            id: publicIp2.id
          }
        }
      }
    ]
  }
}

output virtualNetworkGatewayId string = virtualNetworkGateway.id
output virtualNetworkGatewayPublicIpIds array = [
  publicIp1.id
  publicIp2.id
]

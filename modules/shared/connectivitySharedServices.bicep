// modules/shared/connectivitySharedServices.bicep
@description('Configuration for RTs to create & associate')
param routeTables array

@description('Hub VNet ID')
param hubVnetId string

@description('Customer abbreviation')
param customerAbbreviation string

@description('Azure region')
param region string

@description('Deployment environment')
param environment string

@description('Virtual Network name')
param vnetName string

@description('VNet address space')
param addressPrefix string

@description('Whether to associate NSGs')
param associateNSGs bool = true

@description('Whether to attach route tables')
param attachRouteTable bool = true

@description('On-premises address prefix')
param onPremAddressPrefix string

@description('CreatedBy tag')
param createdBy string

@description('ManagedBy tag')
param managedBy string

@description('Location tag')
param tagLocation string

@description('Application tag')
param applicationTag string = 'Connectivity and Routing'

@description('Function tag') 
param functionTag string = 'Core Management'

@description('Cost Center tag')
param costCenterTag string = 'Core Services'

@description('Subnet configurations')
param subnetConfig array


@description('Private IP address of the Azure Firewall')
param firewallPrivateIpAddress string

var location = region

resource subnetNSGs 'Microsoft.Network/networkSecurityGroups@2023-02-01' = [for subnet in subnetConfig: if (associateNSGs) {
  name: 'nsg-${subnet.name}-vnet-${environment}-sharedservices-${customerAbbreviation}-${region}'
  location: location
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
    securityRules: []
  }
}]

resource vnet 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  name: vnetName
  location: location
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
        routeTable: attachRouteTable ? {
          id: resourceId('Microsoft.Network/routeTables', 'rt-${environment}-sharedservices-${customerAbbreviation}-${region}-hub')
        } : null
        networkSecurityGroup: associateNSGs ? {
          id: resourceId('Microsoft.Network/networkSecurityGroups', 'nsg-${subnet.name}-vnet-${environment}-sharedservices-${customerAbbreviation}-${region}')
        } : null
      }
    }]
  }
}

resource routeTable 'Microsoft.Network/routeTables@2023-02-01' = if (attachRouteTable) {
  name: 'rt-${environment}-sharedservices-${customerAbbreviation}-${region}-hub'
  location: location
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
    disableBgpRoutePropagation: false
    routes: [
      {
        name: 'Route-To-OnPrem'
        properties: {
          addressPrefix: onPremAddressPrefix
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIpAddress
        }
      }
      {
        name: 'vnet-prod-core-management-${customerAbbreviation}-${region}-01'
        properties: {
          addressPrefix: '10.101.248.0/21'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIpAddress
        }
      }
      {
        name: 'vnet-prod-core-identity-${customerAbbreviation}-${region}-01'
        properties: {
          addressPrefix: '10.101.4.0/22'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIpAddress
        }
      }
      {
        name: 'To-WAN'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIpAddress
        }
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
output routeTableIds string = routeTable.id

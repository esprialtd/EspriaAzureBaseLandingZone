// modules/identity/connectivityCoreIdentity.bicep
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

@description('List of subnet names NOT to associate NSGs to')
param excludeFromNsg array = []

var location = region

// Route table creation
resource routeTable 'Microsoft.Network/routeTables@2023-02-01' = if (attachRouteTable) {
  name: 'rt-${environment}-core-identity-${customerAbbreviation}-${region}-hub'
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
        name: 'vnet-prod-sharedservices-${customerAbbreviation}-${region}-01'
        properties: {
          addressPrefix: '10.101.16.0/21'
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

// 1. Create the VNet and subnets (only address prefixes and route tables)
resource vnet 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  name: vnetName
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
  properties: {
    addressSpace: {
      addressPrefixes: [addressPrefix]
    }
    subnets: [
      for subnet in subnetConfig: {
        name: subnet.name
        properties: {
          addressPrefix: subnet.addressPrefix
          routeTable: attachRouteTable ? {
          id: resourceId('Microsoft.Network/routeTables', 'rt-${environment}-core-identity-${customerAbbreviation}-${region}-hub')
        } : null
        }
      }
    ]
  }
}

// 2. Create NSGs for each subnet
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
  for sn in subnetConfig: if (associateNSGs && !contains(excludeFromNsg, sn.name)) {  parent: vnet
  name: sn.name
  properties: {
    networkSecurityGroup: {
      id: resourceId('Microsoft.Network/networkSecurityGroups', 'nsg-${sn.name}-${vnetName}')
    }
  }
  dependsOn: [ vnet, nsgCollection ]
}]





output vnetId string = vnet.id
output routeTableIds string = routeTable.id

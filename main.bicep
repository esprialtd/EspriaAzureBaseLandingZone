// Starter Bicep Landing Zone Structure
// ------------------------------------
// main.bicep - Root orchestration for cross-subscription base landing zone

@description('Customer full name (e.g., Espria)')
param customerName string

@description('Customer abbreviation (e.g., ESP)')
param customerAbbreviation string

@description('Azure region (e.g., uksouth, ukwest)')
@allowed([
  'uksouth'
  'ukwest'
  'northeurope'
  'westeurope'
])
param region string = 'uksouth'

@description('Location for deployments')
param location string = region

@description('Environment (e.g., prod, dev, uat)')
@allowed([
  'prod'
  'dev'
  'uat'
])
param environment string = 'prod'

@description('Core services subscription ID')
param coreSubscriptionId string

@description('Shared services subscription ID')
param sharedSubscriptionId string

@description('CreatedBy tag value')
param createdBy string = 'Espria Ltd'

@description('ManagedBy tag value')
param managedBy string = 'Espria Ltd'

@description('Location tag value')
param tagLocation string = 'UK South'

@description('Admin username for VMs')
param adminUsername string

@secure()
@description('Admin password for VMs')
param adminPassword string

@description('On-premises address prefix (e.g., 10.1.0.0/16)')
param onPremAddressPrefix string = '10.1.0.0/16'

@description('Top-level management group display name')
param topLevelGroupName string = '${customerAbbreviation} - Internal'

@description('Core services management group display name')
param coreServicesGroupName string = '${customerAbbreviation} - Internal - Core Services'

@description('Shared services management group display name')
param sharedServicesGroupName string = '${customerAbbreviation} - Internal - Shared Services'

// Management Groups
module managementGroups 'modules/managementGroups.bicep' = {
  name: 'managementGroups'
  params: {
    customerAbbreviation: customerAbbreviation
    topLevelGroupName: topLevelGroupName
    coreServicesGroupName: coreServicesGroupName
    sharedServicesGroupName: sharedServicesGroupName
    coreSubscriptionId: coreSubscriptionId
    sharedSubscriptionId: sharedSubscriptionId
  }
}

// Core Connectivity Hub VNet (10.101.0.0/21)
module coreConnectivity 'modules/connectivity/connectivityCoreConnectivity.bicep' = {
  name: 'coreConnectivity'
  scope: subscription(coreSubscriptionId)
  params: {
    customerAbbreviation: customerAbbreviation
    region: region
    environment: environment
    addressPrefix: '10.101.0.0/21'
    vnetName: 'vnet-${environment}-core-connectivity-${customerAbbreviation}-${region}-01'
    associateNSGs: true
    attachRouteTable: true
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
    subnetConfig: [
      {
        name: 'GatewaySubnet'
        addressPrefix: '10.101.0.0/27'      
      }
      {
        name: 'AzureFirewallSubnet'
        addressPrefix: '10.101.1.0/24'
      }
      {
        name: 'CoreServices'
        addressPrefix: '10.101.2.0/24'
      }
      {
        name: 'PrivateEndpoint'
        addressPrefix: '10.101.7.0/24'
      }
    ]
  }
}

// Core Virtual Network Gateway (Active-Active)
module coreGateway 'modules/connectivity/vNetGateway.bicep' = {
  name: 'coreGateway'
  scope: subscription(coreSubscriptionId)
  params: {
    customerAbbreviation: customerAbbreviation
    region: region
    environment: environment
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
    vnetName: 'vnet-${environment}-core-connectivity-${customerAbbreviation}-${region}-01'
    gatewaySubnetId: coreConnectivity.outputs.subnetIds.GatewaySubnet
  }
}

// Azure Firewall Deployment in Core Connectivity
module coreFirewall 'modules/connectivity/azFirewall.bicep' = {
  name: 'coreFirewall'
  scope: subscription(coreSubscriptionId)
  params: {
    customerAbbreviation: customerAbbreviation
    region: region
    environment: environment
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
    firewallSubnetId: coreConnectivity.outputs.subnetIds.AzureFirewallSubnet
  }
}

// Variables

var firewallPrivateIp = coreFirewall.outputs.firewallPrivateIpAddress

// Core Identity VNet (10.101.8.0/22)
module coreIdentity 'modules/identity/connectivityCoreIdentity.bicep' = {
  name: 'coreIdentity'
  scope: subscription(coreSubscriptionId)
  params: {
    customerAbbreviation: customerAbbreviation
    region: region
    environment: environment
    addressPrefix: '10.101.8.0/22'
    vnetName: 'vnet-${environment}-core-identity-${customerAbbreviation}-${region}-01'
    associateNSGs: true
    attachRouteTable: true
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
    onPremAddressPrefix: onPremAddressPrefix
    subnetConfig: [
      {
        name: 'DomainControllers'
        addressPrefix: '10.101.8.0/24'
      }
      {
        name: 'EntraDomainServices'
        addressPrefix: '10.101.9.0/24'
      }
      {
        name: 'PrivateEndpoint'
        addressPrefix: '10.101.11.0/24'
      }
    ]
    routeTables: [
      {
        name: 'rt-${environment}-core-identity-${customerAbbreviation}-${region}-hub'
        subnets: [
          'DomainControllers'
          'EntraDomainServices'
          'PrivateEndpoint'
        ]
        routes: [
          {
            name: 'vnet-prod-sharedservices-${customerAbbreviation}-${region}-01'
            addressPrefix: '10.101.16.0/21'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewallPrivateIp
          }
          {
            name: 'vnet-prod-core-management-${customerAbbreviation}-${region}-01'
            addressPrefix: '10.101.248.0/21'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewallPrivateIp
          }
          {
            name: 'To-OnPrem'
            addressPrefix: onPremAddressPrefix
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewallPrivateIp
          }
          {
            name: 'To-WAN'
            addressPrefix: '0.0.0.0/0'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewallPrivateIp
          }
        ]
      }
    ]
    // Link to Core Connectivity VNet for routing
    hubVnetId: coreConnectivity.outputs.vnetId
  }
}

// Core Management VNet (10.101.248.0/21)
module coreManagement 'modules/management/connectivityCoreManagement.bicep' = {
  name: 'coreManagement'
  scope: subscription(coreSubscriptionId)
  params: {
    customerAbbreviation: customerAbbreviation
    region: region
    environment: environment
    addressPrefix: '10.101.248.0/21'
    vnetName: 'vnet-${environment}-core-management-${customerAbbreviation}-${region}-01'
    associateNSGs: true
    attachRouteTable: true
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
    subnetConfig: [
      {
        name: 'ManagementServers'
        addressPrefix: '10.101.248.0/24'
      }
      {
        name: 'AzureBastionSubnet'
        addressPrefix: '10.101.249.0/27'
      }
      {
        name: 'PrivateEndpoint'
        addressPrefix: '10.101.255.0/24'
      }
    ]
    routeTables: [
      {
        name: 'rt-${environment}-core-management-${customerAbbreviation}-${region}-hub'
        subnets: [
          'ManagementServers'
          'AzureBastionSubnet'
          'PrivateEndpoint'
        ]
        routes: [
          {
            name: 'vnet-prod-core-identity-${customerAbbreviation}-${region}-01'
            addressPrefix: '10.101.8.0/22'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewallPrivateIp
          }
          {
            name: 'vnet-prod-sharedservices-${customerAbbreviation}-${region}-01'
            addressPrefix: '10.101.16.0/21'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewallPrivateIp
          }
          {
            name: 'To-OnPrem'
            addressPrefix: onPremAddressPrefix
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewallPrivateIp
          }
          {
            name: 'To-WAN'
            addressPrefix: '0.0.0.0/0'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewallPrivateIp
          }
      ]
     }
    ]
    // Link to Core Connectivity VNet for routing
    hubVnetId: coreConnectivity.outputs.vnetId
  }
}

// Shared Services VNet (10.101.16.0/21)
module sharedServices 'modules/shared/connectivitySharedServices.bicep' = {
  name: 'sharedServices'
  scope: subscription(sharedSubscriptionId)
  params: {
    customerAbbreviation: customerAbbreviation
    region: region
    environment: environment
    addressPrefix: '10.101.16.0/21'
    vnetName: 'vnet-${environment}-sharedservices-${customerAbbreviation}-${region}-01'
    associateNSGs: true
    attachRouteTable: true
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
    subnetConfig: [
      {
        name: 'SharedServices'
        addressPrefix: '10.101.16.0/24'
      }
      {
        name: 'PrivateEndpoint'
        addressPrefix: '10.101.23.0/24'
      }
    ]
    routeTables: [
      {
        name: 'rt-${environment}-sharedservices-${customerAbbreviation}-${region}-hub'
        subnets: [
          'SharedServices'
          'PrivateEndpoint'
        ]
        routes: [
          {
            name: 'vnet-prod-core-identity-${customerAbbreviation}-${region}-01'
            addressPrefix: '10.101.8.0/22'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewallPrivateIp
          }
          {
            name: 'vnet-prod-core-management-${customerAbbreviation}-${region}-01'
            addressPrefix: '10.101.248.0/21'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewallPrivateIp
          }
          {
            name: 'To-OnPrem'
            addressPrefix: onPremAddressPrefix
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewallPrivateIp
          }
          {
            name: 'To-WAN'
            addressPrefix: '0.0.0.0/0'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewallPrivateIp
          }
        ]
     }
    ]
    // Link to Core Connectivity VNet for routing
    hubVnetId: coreConnectivity.outputs.vnetId
  }
}

// Management Server VM
module managementVm 'modules/management/managementVm.bicep' = {
  name: 'managementVm'
  scope: subscription(coreSubscriptionId)
  params: {
    customerAbbreviation: customerAbbreviation
    region: region
    environment: environment
    vnetName: 'vnet-${environment}-core-management-${customerAbbreviation}-${region}-01'
    subnetName: 'ManagementServers'
    adminUsername: adminUsername
    adminPassword: adminPassword
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
  }
}
// Domain Controller VMs
module domainVms 'modules/identity/domainVms.bicep' = {
  name: 'domainVms'
  scope: subscription(coreSubscriptionId)
  params: {
    customerAbbreviation: customerAbbreviation
    region: region
    regionAbbreviation: toUpper(take(region, 2))
    vnetName: 'vnet-${environment}-core-identity-${customerAbbreviation}-${region}-01'
    subnetName: 'DomainControllers'
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}
// Entra Domain Services (AADDS)
module aadds 'modules/identity/aadds.bicep' = {
  name: 'aadds'
  scope: subscription(coreSubscriptionId)
  params: {
    resourceGroupName: 'rg-${environment}-core-identity-${customerAbbreviation}-${region}-01'
    region: region
    domainName: '${customerAbbreviation}.local'
    vnetName: 'vnet-${environment}-core-identity-${customerAbbreviation}-${region}-01'
    subnetName: 'EntraDomainServices'
  }
}
// Azure Files for Shared Services
module azureFiles 'modules/shared/azureFiles.bicep' = {
  name: 'azureFiles'
  scope: subscription(sharedSubscriptionId)
  params: {
    region: region
    vnetName: 'vnet-${environment}-sharedservices-${customerAbbreviation}-${region}-01'
    subnetName: 'PrivateEndpoint'
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
  }
}
// File Server VM
module fileServer 'modules/shared/fileServer.bicep' = {
  name: 'fileServer'
  scope: subscription(sharedSubscriptionId)
  params: {
    customerAbbreviation: customerAbbreviation
    region: region
    vnetName: 'vnet-${environment}-sharedservices-${customerAbbreviation}-${region}-01'
    subnetName: 'SharedServices'
    adminUsername: adminUsername
    adminPassword: adminPassword
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
  }
}

// Print Server VM
module printServer 'modules/shared/printServer.bicep' = {
  name: 'printServer'
  scope: subscription(sharedSubscriptionId)
  params: {
    customerAbbreviation: customerAbbreviation
    region: region
    vnetName: 'vnet-${environment}-sharedservices-${customerAbbreviation}-${region}-01'
    subnetName: 'SharedServices'
    adminUsername: adminUsername
    adminPassword: adminPassword
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
  }
}


// Outputs
output coreVNetId string = coreConnectivity.outputs.vnetId
output identityVNetId string = coreIdentity.outputs.vnetId
output managementVNetId string = coreManagement.outputs.vnetId
output sharedServicesVNetId string = sharedServices.outputs.vnetId
output managementVmId string = managementVm.outputs.vmId
output domainVmsIds array = [for vm in domainVms.outputs.vmIds: vm]
output aaddsId string = aadds.outputs.aaddsId
output azureFilesId string = azureFiles.outputs.azureFilesId
output fileServerId string = fileServer.outputs.fileServerId
output firewallId string = coreFirewall.outputs.firewallId
output firewallPrivateIpAddress string = coreFirewall.outputs.firewallPrivateIpAddress
output virtualNetworkGatewayId string = coreGateway.outputs.virtualNetworkGatewayId
output virtualNetworkGatewayPublicIpId string = coreGateway.outputs.virtualNetworkGatewayPublicIpId
output routeTableIds object = {
  identity: coreIdentity.outputs.routeTableIds
  management: coreManagement.outputs.routeTableIds
  shared: sharedServices.outputs.routeTableIds
}

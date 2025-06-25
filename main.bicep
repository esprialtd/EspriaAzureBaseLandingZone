// Starter Bicep Landing Zone Structure
// ------------------------------------
// main.bicep - Root orchestration for cross-subscription base landing zone


@description('Customer abbreviation 3 character (e.g., ESP)')
param customerAbbreviation string

@description('Customer abbreviation (e.g., ESP)')
param customerAbbreviationlower string = toLower(take(customerAbbreviation,3))

@description('Customer name (e.g., Espria Ltd)')
param customerName string = 'Espria Ltd'

@description('Customer domain name (e.g., espria.co.uk)')
  param customerdomainname string = 'espria.co.uk'

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

@description('Region short name (e.g., UKS,UKW,NEU,WEU)')
param regionAbbreviation string = toUpper(take(region, 3))

@description('Region short name (e.g., UKS,UKW,NEU,WEU)')
param regionAbbreviationlower string = toLower(take(region, 3))

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


// Network Variables

var addressPrefixes = {
  coreConnectivity: '10.101.0.0/21'
  coreIdentity: '10.101.8.0/22'
  coreManagement: '10.101.248.0/21'
  sharedServices: '10.101.16.0/21'
}

var vnetNameCoreConnectivity = 'vnet-${environment}-core-connectivity-${customerAbbreviation}-${region}-01'
var vnetNameCoreIdentity = 'vnet-${environment}-core-identity-${customerAbbreviation}-${region}-01'
var vnetNameCoreManagement = 'vnet-${environment}-core-management-${customerAbbreviation}-${region}-01'
var vnetNameSharedServices = 'vnet-${environment}-sharedservices-${customerAbbreviation}-${region}-01'

targetScope = 'subscription'

// Core Resource Groups
module coreResourceGroups 'modules/coreResourceGroups.bicep' = {
  name: 'coreResourceGroups'
  scope: subscription(coreSubscriptionId)
  params: {
    location: location
    customerAbbreviation: customerAbbreviation
    region: region
    environment: environment
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
  }
}

// Shared Resource Group
module sharedResourceGroups 'modules/sharedResourceGroups.bicep' = {
  name: 'sharedResourceGroups'
  scope: subscription(sharedSubscriptionId)
  params: {
    location: location
    customerAbbreviation: customerAbbreviation
    region: region
    environment: environment
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
  }
}
var rgCoreConnectivity string = 'rg-${environment}-core-connectivity-${customerAbbreviation}-${region}-01'
var rgCoreIdentity string = 'rg-${environment}-core-identity-${customerAbbreviation}-${region}-01'
var rgCoreManagement string = 'rg-${environment}-core-management-${customerAbbreviation}-${region}-01'
var rgSharedServices string = 'rg-${environment}-sharedservices-${customerAbbreviation}-${region}-01'

// Management Groups
// module managementGroups 'modules/managementGroups.bicep' = {
//   name: 'managementGroups'
//   scope: tenant()
//   params: {
//     customerName: customerName
//   }
// }

// Core Connectivity Hub VNet (10.101.0.0/21)
module connectivityCoreConnectivity 'modules/connectivity/connectivityCoreConnectivity.bicep' = {
  name: 'connectivityCoreConnectivity'
  scope: resourceGroup(coreSubscriptionId, rgCoreConnectivity)
  dependsOn: [coreResourceGroups]
  params: {
    region: region
    environment: environment
    associateNSGs: true
    customerAbbreviation: customerAbbreviation
    addressPrefix: addressPrefixes.coreConnectivity
    vnetName: vnetNameCoreConnectivity
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
    excludeFromNsg : [
      'GatewaySubnet'
      'AzureFirewallSubnet'
    ]
    subnetConfig: [
      {
        name: 'GatewaySubnet'
        addressPrefix: '10.101.0.0/26'      
      }
      {
        name: 'AzureFirewallSubnet'
        addressPrefix: '10.101.0.64/26'
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
  scope: resourceGroup(coreSubscriptionId, rgCoreConnectivity)
  dependsOn: [coreResourceGroups]
  params: {
    customerAbbreviation: customerAbbreviation
    region: region
    environment: environment
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
    gatewaySubnetId: connectivityCoreConnectivity.outputs.subnetIds.GatewaySubnet
  }
}

// Azure Firewall Deployment in Core Connectivity
module coreFirewall 'modules/connectivity/azFirewall.bicep' = {
  name: 'coreFirewall'
  scope: resourceGroup(coreSubscriptionId, rgCoreConnectivity)
  dependsOn: [coreResourceGroups]
  params: {
    customerAbbreviation: customerAbbreviation
    region: region
    environment: environment
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
    firewallSubnetId: connectivityCoreConnectivity.outputs.subnetIds.AzureFirewallSubnet
  }
}

// Variables

var firewallPrivateIp = coreFirewall.outputs.firewallPrivateIpAddress

// Core Identity VNet (10.101.8.0/22)
module connectivityCoreIdentity 'modules/identity/connectivityCoreIdentity.bicep' = {
  name: 'connectivityCoreIdentity'
  scope: resourceGroup(coreSubscriptionId, rgCoreIdentity)
  dependsOn: [coreResourceGroups]
  params: {
    customerAbbreviation: customerAbbreviation
    region: region
    environment: environment
    addressPrefix: addressPrefixes.coreIdentity
    vnetName: vnetNameCoreIdentity
    associateNSGs: true
    attachRouteTable: true
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
    onPremAddressPrefix: onPremAddressPrefix
    firewallPrivateIpAddress: firewallPrivateIp
    excludeFromNsg : [
      'EntraDomainServices'
    ]
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
            name: vnetNameSharedServices
            addressPrefix: '10.101.16.0/21'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewallPrivateIp
          }
          {
            name: vnetNameCoreManagement
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
    hubVnetId: connectivityCoreConnectivity.outputs.vnetId
  }
}

// Core Management VNet (10.101.248.0/21)
module connectivityCoreManagement 'modules/management/connectivityCoreManagement.bicep' = {
  name: 'connectivityCoreManagement'
  scope: resourceGroup(coreSubscriptionId, rgCoreManagement)
  dependsOn: [coreResourceGroups]
  params: {
    customerAbbreviation: customerAbbreviation
    region: region
    environment: environment
    addressPrefix: addressPrefixes.coreManagement
    vnetName: vnetNameCoreManagement
    associateNSGs: true
    attachRouteTable: true
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
    firewallPrivateIpAddress: firewallPrivateIp
    onPremAddressPrefix: onPremAddressPrefix
    excludeFromNsg : [
      'AzureBastionSubnet'
    ]
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
            name: vnetNameCoreIdentity
            addressPrefix: '10.101.8.0/22'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewallPrivateIp
          }
          {
            name: vnetNameSharedServices
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
    hubVnetId: connectivityCoreConnectivity.outputs.vnetId
  }
}

// Shared Services VNet (10.101.16.0/21)
module connectivitySharedServices 'modules/shared/connectivitySharedServices.bicep' = {
  name: 'sharedSconnectivitySharedServiceservices'
  scope: resourceGroup(sharedSubscriptionId, rgSharedServices)
  dependsOn: [sharedResourceGroups]
  params: {
    customerAbbreviation: customerAbbreviation
    region: region
    environment: environment
    addressPrefix: addressPrefixes.sharedServices
    vnetName: vnetNameSharedServices
    associateNSGs: true
    attachRouteTable: true
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
    onPremAddressPrefix: onPremAddressPrefix
    firewallPrivateIpAddress: firewallPrivateIp
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
            name: vnetNameCoreIdentity
            addressPrefix: '10.101.8.0/22'
            nextHopType: 'VirtualAppliance'
            nextHopIpAddress: firewallPrivateIp
          }
          {
            name: vnetNameCoreManagement
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
    hubVnetId: connectivityCoreConnectivity.outputs.vnetId
  }
}

// Management Server VM
module managementVm 'modules/management/managementVm.bicep' = {
  name: 'managementVm'
  scope: resourceGroup(coreSubscriptionId, rgCoreManagement)
  dependsOn: [connectivityCoreManagement]
  params: {
    customerAbbreviation: customerAbbreviation
    region: region
    environment: environment
    vnetName: vnetNameCoreManagement
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
  scope: resourceGroup(coreSubscriptionId, rgCoreIdentity)
  dependsOn: [connectivityCoreIdentity]
  params: {
    customerAbbreviation: customerAbbreviation
    region: region
    regionAbbreviation: regionAbbreviation
    vnetName: vnetNameCoreIdentity
    subnetName: 'DomainControllers'
    environment: environment
    adminUsername: adminUsername
    adminPassword: adminPassword
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
  }
}
// Entra Domain Services (AADDS)
module aadds 'modules/identity/aadds.bicep' = {
  name: 'aadds'
  scope: resourceGroup(coreSubscriptionId, rgCoreIdentity)
  dependsOn: [connectivityCoreIdentity]
  params: {
    region: region
    domainName: '${customerdomainname}'
    vnetName: vnetNameCoreIdentity
    subnetName: 'EntraDomainServices'
    environment: environment
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
  }
}
// Azure Files for Shared Services
module azureFiles 'modules/shared/azureFiles.bicep' = {
  name: 'azureFiles'
  scope: resourceGroup(coreSubscriptionId, rgCoreIdentity)
  dependsOn: [sharedResourceGroups]
  params: {
    region: region
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
    environment: environment
    storageAccountName: 'stfiles${environment}${customerAbbreviationlower}${regionAbbreviationlower}01'
    fileShareName: 'sharedfiles'
    vnetId: connectivitySharedServices.outputs.vnetId
  }
}
// File Server VM
module fileServer 'modules/shared/fileVm.bicep' = {
  name: 'fileServer'
  scope: resourceGroup(sharedSubscriptionId, rgSharedServices)
  dependsOn: [connectivitySharedServices]
  params: {
    vnetName: vnetNameSharedServices
    subnetName: 'SharedServices'
    adminUsername: adminUsername
    adminPassword: adminPassword
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
    location: location
    environment: environment
    fsnamePrefix: '${customerAbbreviation}-AZ${regionAbbreviation}-FS01'
  }
}

// Print Server VM
module printServer 'modules/shared/printVm.bicep' = {
  name: 'printServer'
  scope: resourceGroup(sharedSubscriptionId, rgSharedServices)
  dependsOn: [connectivitySharedServices]
  params: {
    vnetName: vnetNameSharedServices
    subnetName: 'SharedServices'
    adminUsername: adminUsername
    adminPassword: adminPassword
    createdBy: createdBy
    managedBy: managedBy
    tagLocation: tagLocation
    location: location
    environment: environment
    prtnamePrefix: '${customerAbbreviation}-AZ${regionAbbreviation}-PRT01'
  }
}


// Outputs
output coreVNetId string = connectivityCoreConnectivity.outputs.vnetId
output identityVNetId string = connectivityCoreIdentity.outputs.vnetId
output managementVNetId string = connectivityCoreManagement.outputs.vnetId
output sharedServicesVNetId string = connectivitySharedServices.outputs.vnetId
output managementVmId string = managementVm.outputs.managementServerId
output domainVmsIds array = domainVms.outputs.vmIds
output aaddsId string = aadds.outputs.aaddsId
output azureFilesId string = azureFiles.outputs.azureFilesId
output fileServerId string = fileServer.outputs.fileServerId
output firewallId string = coreFirewall.outputs.firewallId
output firewallPrivateIpAddress string = coreFirewall.outputs.firewallPrivateIpAddress
output virtualNetworkGatewayId string = coreGateway.outputs.virtualNetworkGatewayId
output virtualNetworkGatewayPublicIpId array = coreGateway.outputs.virtualNetworkGatewayPublicIpIds
output routeTableIds object = {
  identity: connectivityCoreIdentity.outputs.routeTableIds
  management: connectivityCoreManagement.outputs.routeTableIds
  shared: connectivitySharedServices.outputs.routeTableIds
}

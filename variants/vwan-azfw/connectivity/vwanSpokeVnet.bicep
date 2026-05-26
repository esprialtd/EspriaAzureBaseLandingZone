// =============================================================================
// variants/vwan-azfw/connectivity/vwanSpokeVnet.bicep
// Spoke VNet for vWAN variant (Identity or Management).
//
// Key differences from hub-spoke spoke VNet:
//   - NO UDRs – vWAN routing intent handles default route injection
//   - NO VNet peering to hub – connection is via hubVirtualNetworkConnections
//   - DNS still set to Domain Controller static IPs
//   - NSGs still applied per subnet for defence-in-depth
//   - Subnets are purpose-specific: DomainControllers, ManagementServers,
//     AzureBastionSubnet (management spoke only), PrivateEndpoint
//
// This module produces the VNet and subnets. The vwanHub.bicep module
// creates the hub connection referencing this VNet's resource ID.
// =============================================================================

param location string
param environment string
param customerAbbreviation string
param regionAbbreviation string
param vnetName string
param addressPrefix string
param siteOctet int

@description('Spoke type: identity or management')
@allowed(['identity', 'management'])
param spokeType string

@description('DNS server IPs to set on the VNet (DC static IPs for identity; empty for DHCP default on management before DCs are up)')
param dnsServerIps array = []

param tags object

var custAbbr = toUpper(customerAbbreviation)
var env      = environment

// Subnet prefixes (same address scheme as hub-spoke for consistency)
var subnetDomainControllers = '10.${siteOctet}.8.0/24'    // Identity only
var subnetPrivEpIdentity    = '10.${siteOctet}.11.0/24'   // Identity PrivateEndpoint
var subnetMgmtServers       = '10.${siteOctet}.248.0/24'  // Management only
var subnetBastion           = '10.${siteOctet}.249.0/26'  // Management AzureBastionSubnet
var subnetPrivEpMgmt        = '10.${siteOctet}.255.0/24'  // Management PrivateEndpoint

// NSGs
resource nsgDomainControllers 'Microsoft.Network/networkSecurityGroups@2023-06-01' = if (spokeType == 'identity') {
  name: 'nsg-DomainControllers-${vnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-AD-Inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: '10.0.0.0/8'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'Deny-Internet-Inbound'
        properties: {
          priority: 4000
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource nsgMgmtServers 'Microsoft.Network/networkSecurityGroups@2023-06-01' = if (spokeType == 'management') {
  name: 'nsg-ManagementServers-${vnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-Bastion-Inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'AzureBastionSubnet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: ['3389', '22']
        }
      }
    ]
  }
}

resource nsgPrivEp 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: 'nsg-PrivateEndpoint-${vnetName}'
  location: location
  tags: tags
  properties: { securityRules: [] }
}

// VNet with subnets for identity spoke
resource identityVnet 'Microsoft.Network/virtualNetworks@2023-06-01' = if (spokeType == 'identity') {
  name: vnetName
  location: location
  tags: union(tags, { Function: 'Identity-Spoke', SpokeType: 'identity' })
  properties: {
    addressSpace: { addressPrefixes: [addressPrefix] }
    dhcpOptions:  length(dnsServerIps) > 0 ? { dnsServers: dnsServerIps } : null
    subnets: [
      {
        name: 'DomainControllers'
        properties: {
          addressPrefix: subnetDomainControllers
          networkSecurityGroup: { id: nsgDomainControllers.id }
        }
      }
      {
        name: 'PrivateEndpoint'
        properties: {
          addressPrefix: subnetPrivEpIdentity
          networkSecurityGroup: { id: nsgPrivEp.id }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// VNet with subnets for management spoke
resource managementVnet 'Microsoft.Network/virtualNetworks@2023-06-01' = if (spokeType == 'management') {
  name: vnetName
  location: location
  tags: union(tags, { Function: 'Management-Spoke', SpokeType: 'management' })
  properties: {
    addressSpace: { addressPrefixes: [addressPrefix] }
    dhcpOptions:  length(dnsServerIps) > 0 ? { dnsServers: dnsServerIps } : null
    subnets: [
      {
        name: 'ManagementServers'
        properties: {
          addressPrefix: subnetMgmtServers
          networkSecurityGroup: { id: nsgMgmtServers.id }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: subnetBastion
          // NSG not supported on AzureBastionSubnet
        }
      }
      {
        name: 'PrivateEndpoint'
        properties: {
          addressPrefix: subnetPrivEpMgmt
          networkSecurityGroup: { id: nsgPrivEp.id }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Outputs – unified regardless of spoke type
// ---------------------------------------------------------------------------
output vnetId           string = spokeType == 'identity' ? identityVnet.id : managementVnet.id
output vnetName         string = vnetName
output bastionSubnetId  string = spokeType == 'management'
  ? resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureBastionSubnet')
  : ''

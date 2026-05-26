// =============================================================================
// variants/vwan-azfw/connectivity/vwanHub.bicep
// Azure Virtual WAN Hub with Azure Firewall (Secured Virtual Hub)
//
// Deploys per region:
//   - Azure Virtual WAN (Standard – required for Azure Firewall in hub)
//     Global resource: only deployed when isPrimaryRegion = true
//   - Azure Virtual Hub (regional, /23 minimum address space)
//   - Azure Firewall Premium in the hub (Secured Virtual Hub pattern)
//   - Azure Firewall Policy (Premium tier – IDPS, TLS inspection capable)
//   - vWAN Hub Routing Intent (force all Internet + Private traffic via AZFW)
//   - Spoke VNet connections for identity and management VNets
//   - Azure Bastion subnet is in the management spoke, not the hub
//
// Key differences from hub-spoke NVA model:
//   - No VNet peering required – vWAN hub manages spoke connections natively
//   - No UDRs on spokes – vWAN routing intent injects routes automatically
//   - Azure Firewall replaces Sophos XG – no VM-based NVA
//   - Hub-to-hub transit is automatic via vWAN global routing
//   - VPN Gateway and ExpressRoute Gateway can be added to the vWAN hub
// =============================================================================

param location string
param environment string
param customerAbbreviation string
param regionAbbreviation string
param vwanId string              // Resource ID of the shared vWAN (global resource)

@description('vWAN hub address prefix – minimum /23, must not overlap with any spoke')
param hubAddressPrefix string    // e.g. 10.101.128.0/23

@description('Identity spoke VNet resource ID to connect to this hub')
param identityVnetId string

@description('Management spoke VNet resource ID to connect to this hub')
param managementVnetId string

@description('Azure Firewall SKU tier')
@allowed(['Premium', 'Standard'])
param firewallSkuTier string = 'Premium'

param tags object

var custAbbr = toUpper(customerAbbreviation)
var regAbbr  = toUpper(regionAbbreviation)
var env      = environment

var hubName          = 'hub-vwan-${env}-core-connectivity-${custAbbr}-${location}-01'
var firewallName     = 'azfw-${env}-core-connectivity-${custAbbr}-${location}-01'
var firewallPipName  = 'pip-azfw-${env}-core-connectivity-${custAbbr}-${location}-01'
var fwPolicyName     = 'fwpol-${env}-core-${custAbbr}-${location}-01'

// ---------------------------------------------------------------------------
// Azure Firewall Policy
// Premium tier enables IDPS, URL filtering, and TLS inspection.
// A shared policy allows child policies per workload spoke (inheritance).
// ---------------------------------------------------------------------------
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-06-01' = {
  name: fwPolicyName
  location: location
  tags: union(tags, { Function: 'Hub-Connectivity', Purpose: 'Firewall-Policy' })
  properties: {
    sku: {
      tier: firewallSkuTier
    }
    threatIntelMode: 'Alert'
    insights: {
      isEnabled:         true
      retentionDays:     30
    }
    dnsSettings: {
      enableProxy: true
    }
  }
}

// Base rule collection: allow management spoke to reach identity (DC DNS)
resource baseRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-06-01' = {
  parent: firewallPolicy
  name: 'DefaultRuleCollectionGroup'
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name:               'AllowInternalDNS'
        priority:           100
        action: { type: 'Allow' }
        rules: [
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-DNS-To-DCs'
            protocols:            ['UDP', 'TCP']
            sourceAddresses:      ['10.0.0.0/8']
            destinationAddresses: ['10.0.0.0/8']
            destinationPorts:     ['53']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-Internal-RFC1918'
            protocols:            ['Any']
            sourceAddresses:      ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']
            destinationAddresses: ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']
            destinationPorts:     ['*']
          }
        ]
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Virtual Hub
// Represents the regional hub managed by vWAN. The hub is where Azure
// Firewall is injected as a "secured virtual hub" resource.
// ---------------------------------------------------------------------------
resource vhub 'Microsoft.Network/virtualHubs@2023-06-01' = {
  name: hubName
  location: location
  tags: union(tags, { Function: 'Hub-Connectivity', Purpose: 'vWAN-Hub' })
  properties: {
    virtualWan: { id: vwanId }
    addressPrefix:   hubAddressPrefix
    sku:             'Standard'
    allowBranchToBranchTraffic: true
  }
}

// ---------------------------------------------------------------------------
// Azure Firewall in the vWAN Hub (Secured Virtual Hub)
// No AzureFirewallSubnet needed – the hub manages its own internal subnet.
// The firewall gets a private IP automatically from the hub address space.
// ---------------------------------------------------------------------------
resource azureFirewall 'Microsoft.Network/azureFirewalls@2023-06-01' = {
  name: firewallName
  location: location
  tags: union(tags, { Function: 'Hub-Connectivity', Purpose: 'Azure-Firewall' })
  properties: {
    sku: {
      name: 'AZFW_Hub'
      tier: firewallSkuTier
    }
    firewallPolicy: { id: firewallPolicy.id }
    virtualHub:     { id: vhub.id }
    hubIPAddresses: {
      publicIPs: {
        count: 1
      }
    }
  }
  dependsOn: [vhub]
}

// ---------------------------------------------------------------------------
// vWAN Hub Routing Intent
// Forces ALL internet-bound and private traffic through Azure Firewall.
// This replaces per-spoke UDRs – the hub propagates routes automatically.
// ---------------------------------------------------------------------------
resource routingIntent 'Microsoft.Network/virtualHubs/routingIntent@2023-06-01' = {
  parent: vhub
  name:   '${hubName}-routing-intent'
  properties: {
    routingPolicies: [
      {
        name: 'InternetTrafficPolicy'
        destinations:         ['Internet']
        nextHop:              azureFirewall.id
      }
      {
        name: 'PrivateTrafficPolicy'
        destinations:         ['PrivateTraffic']
        nextHop:              azureFirewall.id
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Spoke VNet Connections to the vWAN Hub
// These replace VNet peering. The hub propagates routes to all connections.
// ---------------------------------------------------------------------------
resource identitySpokeConnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-06-01' = {
  parent: vhub
  name:   'conn-identity-${regAbbr}'
  properties: {
    remoteVirtualNetwork:    { id: identityVnetId }
    enableInternetSecurity:  true
    routingConfiguration: {
      associatedRouteTable:  { id: '${vhub.id}/hubRouteTables/defaultRouteTable' }
      propagatedRouteTables: {
        labels:     ['default']
        ids:        [{ id: '${vhub.id}/hubRouteTables/defaultRouteTable' }]
      }
    }
  }
  dependsOn: [routingIntent]
}

resource managementSpokeConnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-06-01' = {
  parent: vhub
  name:   'conn-management-${regAbbr}'
  properties: {
    remoteVirtualNetwork:    { id: managementVnetId }
    enableInternetSecurity:  true
    routingConfiguration: {
      associatedRouteTable:  { id: '${vhub.id}/hubRouteTables/defaultRouteTable' }
      propagatedRouteTables: {
        labels:     ['default']
        ids:        [{ id: '${vhub.id}/hubRouteTables/defaultRouteTable' }]
      }
    }
  }
  dependsOn: [routingIntent]
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output vhubId             string = vhub.id
output vhubName           string = vhub.name
output firewallId         string = azureFirewall.id
output firewallName       string = azureFirewall.name
output firewallPrivateIp  string = azureFirewall.properties.hubIPAddresses.privateIPAddress
output firewallPolicyId   string = firewallPolicy.id
// vWAN hubs do not have a BastionSubnet – Bastion is in the management spoke
// Spoke connections replace peering – outputs match the hub-spoke contract
output hubConnectivityType string = 'vwan'

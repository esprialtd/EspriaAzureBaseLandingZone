// =============================================================================
// variants/vwan-azfw/connectivity/vwanHub.bicep
// Azure Virtual WAN Hub with Azure Firewall (Secured Virtual Hub)
//
// Deploys per region:
//   - Azure Virtual Hub (regional, 10.{siteId}.0.0/23 — mirrors the
//     connectivity VNet address space used in hub-spoke variants)
//   - Azure Firewall Premium in the hub (Secured Virtual Hub pattern)
//   - Azure Firewall Policy (Premium tier – IDPS, TLS inspection capable)
//   - vWAN Hub Routing Intent (force all Internet + Private traffic via AZFW)
//   - Spoke VNet connections for identity and management VNets
//   - vWAN VPN Gateway (optional – gated by deployVpnGateway param)
//
// Address space note:
//   The hub sits at 10.{siteId}.0.0/23 — the same range that the Sophos NVA
//   hub-spoke variant uses for its connectivity VNet. Since vWAN replaces that
//   VNet entirely, reusing the same block keeps the per-site /16 layout
//   consistent across all three variants:
//     10.x.0.0/23   → vWAN Hub (this module)
//     10.x.8.0/22   → Identity spoke
//     10.x.248.0/21 → Management spoke
//
// Hub-to-hub transit is automatic via vWAN global routing — no explicit
// peering required. The VPN Gateway (optional) is the vWAN-native type
// (Microsoft.Network/vpnGateways), not a standalone virtualNetworkGateway.
// =============================================================================

param location string
param environment string
param customerAbbreviation string
param regionAbbreviation string
param vwanId string

@description('vWAN Hub address prefix. Minimum /23. Default uses 10.{siteId}.0.0/23 — mirrors the connectivity VNet block in hub-spoke variants.')
param hubAddressPrefix string

@description('Identity spoke VNet resource ID to connect to this hub')
param identityVnetId string

@description('Management spoke VNet resource ID to connect to this hub')
param managementVnetId string

@description('Azure Firewall SKU tier')
@allowed(['Premium', 'Standard'])
param firewallSkuTier string = 'Premium'

@description('Deploy a vWAN VPN Gateway in this hub. Adds ~30 minutes to provisioning time.')
param deployVpnGateway bool = false

@description('VPN Gateway scale unit. 1 = 500 Mbps, 2 = 1 Gbps. Each scale unit is an active-active pair.')
@minValue(1)
@maxValue(20)
param vpnGwScaleUnit int = 1

@allowed(['adds', 'entrads'])
@description('Identity type determines the firewall rule set (adds = IaaS DCs, entrads = Entra DS managed domain).')
param identityType string = 'entrads'

@description('Secondary region site octet for firewall rules. Pass 0 if secondary not deployed.')
param secondarySiteOctet int = 0

@description('Deploy secondary region rules in the firewall policy.')
param deploySecondaryRegionRules bool = true

@description('Primary site octet for firewall rules — derived from hub address prefix.')
param primarySiteOctet int

@description('On-premises address prefix for firewall rules.')
param onPremAddressPrefix string = '10.1.0.0/16'

param tags object

var custAbbr = toUpper(customerAbbreviation)
var env      = environment

var hubName         = 'hub-vwan-${env}-core-connectivity-${custAbbr}-${location}-01'
var firewallName    = 'azfw-${env}-core-connectivity-${custAbbr}-${location}-01'
var fwPolicyName    = 'fwpol-${env}-core-${custAbbr}-${location}-01'
var vpnGwName       = 'vnet-gw-${env}-core-connectivity-${custAbbr}-${location}-01'

// ---------------------------------------------------------------------------
// Azure Firewall Policy — shared module with structured rule sets
// ---------------------------------------------------------------------------
module fwPolicy '../../../shared/connectivity/firewallPolicy.bicep' = {
  name: 'deploy-fw-policy-${location}'
  params: {
    location:              location
    environment:           environment
    customerAbbreviation:  customerAbbreviation
    firewallSkuTier:       firewallSkuTier
    identityType:          identityType
    primarySiteOctet:      primarySiteOctet
    secondarySiteOctet:    secondarySiteOctet
    deploySecondaryRegion: deploySecondaryRegionRules
    onPremAddressPrefix:   onPremAddressPrefix
    tags:                  tags
  }
}

// ---------------------------------------------------------------------------
// Virtual Hub
// ---------------------------------------------------------------------------
resource vhub 'Microsoft.Network/virtualHubs@2023-06-01' = {
  name: hubName
  location: location
  tags: union(tags, { Function: 'Hub-Connectivity', Purpose: 'vWAN-Hub' })
  properties: {
    virtualWan:    { id: vwanId }
    addressPrefix: hubAddressPrefix
    sku:           'Standard'
    allowBranchToBranchTraffic: true
  }
}

// ---------------------------------------------------------------------------
// Azure Firewall – Secured Virtual Hub pattern
// SKU name must be AZFW_Hub (not AZFW_VNet) — the hub manages the internal
// subnet; no AzureFirewallSubnet is needed or allowed.
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
    firewallPolicy: { id: fwPolicy.outputs.firewallPolicyId }
    virtualHub:     { id: vhub.id }
    hubIPAddresses: {
      publicIPs: { count: 1 }
    }
  }
  dependsOn: [vhub]
}

// ---------------------------------------------------------------------------
// vWAN Hub Routing Intent
// Forces all Internet and Private traffic through the Azure Firewall.
// Replaces per-spoke UDRs — the hub propagates default routes automatically.
// Must be deployed after the Firewall so the Firewall ID is known.
// ---------------------------------------------------------------------------
resource routingIntent 'Microsoft.Network/virtualHubs/routingIntent@2023-06-01' = {
  parent: vhub
  name:   '${hubName}-routing-intent'
  properties: {
    routingPolicies: [
      {
        name:         'InternetTrafficPolicy'
        destinations: ['Internet']
        nextHop:      azureFirewall.id
      }
      {
        name:         'PrivateTrafficPolicy'
        destinations: ['PrivateTraffic']
        nextHop:      azureFirewall.id
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// vWAN VPN Gateway (optional)
// Microsoft.Network/vpnGateways is the vWAN-native gateway type — distinct
// from Microsoft.Network/virtualNetworkGateways used in hub-spoke variants.
// It is injected into the vWAN hub directly; no GatewaySubnet is required.
//
// Scale unit defines throughput and instance count:
//   1 scale unit = 500 Mbps aggregate, active-active pair
//   2 scale units = 1 Gbps aggregate
// BGP is enabled by default; ASN is auto-assigned by Azure (65515).
// Provisioning a vWAN VPN Gateway takes approximately 30 minutes.
// ---------------------------------------------------------------------------
resource vpnGateway 'Microsoft.Network/vpnGateways@2023-06-01' = if (deployVpnGateway) {
  name: vpnGwName
  location: location
  tags: union(tags, { Function: 'Hub-Connectivity', Purpose: 'vWAN-VPN-Gateway' })
  properties: {
    virtualHub:  { id: vhub.id }
    bgpSettings: {
      asn:                 65515    // Azure-reserved ASN for vWAN gateways
      peerWeight:          0
      bgpPeeringAddresses: []       // Auto-assigned per instance
    }
    vpnGatewayScaleUnit: vpnGwScaleUnit
    isRoutingPreferenceInternet: false
  }
  dependsOn: [routingIntent]
}

// ---------------------------------------------------------------------------
// Spoke VNet Connections
// ---------------------------------------------------------------------------
resource identitySpokeConnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-06-01' = {
  parent: vhub
  name:   'conn-identity-${regionAbbreviation}'
  properties: {
    remoteVirtualNetwork:   { id: identityVnetId }
    enableInternetSecurity: true
    routingConfiguration: {
      associatedRouteTable:  { id: '${vhub.id}/hubRouteTables/defaultRouteTable' }
      propagatedRouteTables: {
        labels: ['default']
        ids:    [{ id: '${vhub.id}/hubRouteTables/defaultRouteTable' }]
      }
    }
  }
  dependsOn: [routingIntent]
}

resource managementSpokeConnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-06-01' = {
  parent: vhub
  name:   'conn-management-${regionAbbreviation}'
  properties: {
    remoteVirtualNetwork:   { id: managementVnetId }
    enableInternetSecurity: true
    routingConfiguration: {
      associatedRouteTable:  { id: '${vhub.id}/hubRouteTables/defaultRouteTable' }
      propagatedRouteTables: {
        labels: ['default']
        ids:    [{ id: '${vhub.id}/hubRouteTables/defaultRouteTable' }]
      }
    }
  }
  dependsOn: [routingIntent]
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output vhubId              string = vhub.id
output vhubName            string = vhub.name
output firewallId          string = azureFirewall.id
output firewallName        string = azureFirewall.name
output firewallPrivateIp   string = azureFirewall.properties.hubIPAddresses.privateIPAddress
output firewallPolicyId    string = fwPolicy.outputs.firewallPolicyId
output vpnGatewayId        string = deployVpnGateway ? vpnGateway.id : ''
output vpnGatewayDeployed  bool   = deployVpnGateway
output hubConnectivityType string = 'vwan'

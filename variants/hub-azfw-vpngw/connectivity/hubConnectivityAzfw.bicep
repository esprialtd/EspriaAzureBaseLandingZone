// =============================================================================
// variants/hub-azfw-vpngw/connectivity/hubConnectivityAzfw.bicep
// Hub VNet for the Azure Firewall + Active-Active VPN Gateway variant.
//
// Differences from Sophos NVA hub:
//   - No NVA subnets (NVALAN, NVAWAN) — replaced by AzureFirewallSubnet
//   - AzureFirewallSubnet /26 (minimum required by Azure, cannot be renamed)
//   - GatewaySubnet /27 (now actually used – VPN Gateway deployed here)
//   - Azure Firewall Premium deployed in AzureFirewallSubnet
//   - Active-Active VPN Gateway deployed in GatewaySubnet (two PIPs, two BGP IPs)
//   - UDRs on spokes point 0.0.0.0/0 to Azure Firewall private IP
//   - Azure Firewall policy is a first-class resource (child of this module)
//   - No VM-based NVA — no admin credentials needed in this module
//
// Active-Active VPN Gateway:
//   - Requires two public IPs
//   - Both instances have unique BGP peering addresses
//   - enableActiveActiveFeature = true
//   - On-premises peer must support BGP (IKEv2 recommended)
//   - VpnGw1AZ SKU chosen: zone-redundant, supports active-active + BGP
// =============================================================================

param location string
param environment string
param customerAbbreviation string
param regionAbbreviation string
param vnetName string
param addressPrefix string
param siteOctet int
param onPremAddressPrefix string = '10.1.0.0/16'

@description('Azure Firewall SKU tier. Premium recommended for IDPS.')
@allowed(['Premium', 'Standard'])
param firewallSkuTier string = 'Premium'

@description('VPN Gateway SKU. VpnGw1AZ recommended for zone-redundant active-active.')
@allowed(['VpnGw1AZ', 'VpnGw2AZ', 'VpnGw3AZ', 'VpnGw1', 'VpnGw2', 'VpnGw3'])
param vpnGwSku string = 'VpnGw1AZ'

@description('BGP ASN for this side of the VPN. Must differ from on-premises ASN.')
param bgpAsn int = 65000

param tags object

var custAbbr = toUpper(customerAbbreviation)
var env      = environment

// Subnet prefixes – AzureFirewallSubnet and GatewaySubnet are mandatory names
var subnetAzureFirewall = '10.${siteOctet}.0.0/26'    // AzureFirewallSubnet (required name, min /26)
var subnetGateway       = '10.${siteOctet}.0.128/27'  // GatewaySubnet (required name)
var subnetRouteServer   = '10.${siteOctet}.0.160/27'  // RouteServerSubnet – reserved
var subnetBastion       = '10.${siteOctet}.1.0/26'    // AzureBastionSubnet
var subnetPrivEp        = '10.${siteOctet}.7.0/24'    // PrivateEndpoint

// Azure Firewall always gets static private IP = first usable in its subnet
var firewallPrivateIp = '10.${siteOctet}.0.4'

var firewallName    = 'azfw-${env}-core-connectivity-${custAbbr}-${location}-01'
var fwPolicyName    = 'fwpol-${env}-core-${custAbbr}-${location}-01'
var vpnGwName       = 'vnet-gw-${env}-core-connectivity-${custAbbr}-${location}-01'
var pipFwName       = 'pip-azfw-${env}-core-${custAbbr}-${location}-01'
var pipVpnGw1Name   = 'pip-vnet-gw-${env}-core-connectivity-${custAbbr}-${location}-01'
var pipVpnGw2Name   = 'pip-vnet-gw-${env}-core-connectivity-${custAbbr}-${location}-02'

// ---------------------------------------------------------------------------
// Public IPs
// ---------------------------------------------------------------------------
resource pipFirewall 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: pipFwName
  location: location
  tags: tags
  sku: { name: 'Standard', tier: 'Regional' }
  zones: ['1', '2', '3']
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion:   'IPv4'
  }
}

// Active-Active VPN Gateway requires TWO public IPs – one per instance
resource pipVpnGw1 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: pipVpnGw1Name
  location: location
  tags: tags
  sku: { name: 'Standard', tier: 'Regional' }
  zones: ['1', '2', '3']
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion:   'IPv4'
  }
}

resource pipVpnGw2 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: pipVpnGw2Name
  location: location
  tags: tags
  sku: { name: 'Standard', tier: 'Regional' }
  zones: ['1', '2', '3']
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion:   'IPv4'
  }
}

// ---------------------------------------------------------------------------
// Hub VNet
// ---------------------------------------------------------------------------
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: vnetName
  location: location
  tags: union(tags, { Function: 'Hub-Connectivity', Purpose: 'Hub-VNet-AZFW' })
  properties: {
    addressSpace: { addressPrefixes: [addressPrefix] }
    subnets: [
      {
        name: 'AzureFirewallSubnet'      // REQUIRED name – Azure enforces this
        properties: {
          addressPrefix: subnetAzureFirewall
          // NSG is NOT supported on AzureFirewallSubnet
        }
      }
      {
        name: 'GatewaySubnet'            // REQUIRED name for VPN/ER Gateways
        properties: {
          addressPrefix: subnetGateway
          // NSG not recommended on GatewaySubnet
        }
      }
      {
        name: 'RouteServerSubnet'
        properties: { addressPrefix: subnetRouteServer }
      }
      {
        name: 'AzureBastionSubnet'
        properties: { addressPrefix: subnetBastion }
      }
      {
        name: 'PrivateEndpoint'
        properties: {
          addressPrefix: subnetPrivEp
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Azure Firewall Policy (Premium)
// ---------------------------------------------------------------------------
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-06-01' = {
  name: fwPolicyName
  location: location
  tags: union(tags, { Function: 'Hub-Connectivity', Purpose: 'Firewall-Policy' })
  properties: {
    sku: { tier: firewallSkuTier }
    threatIntelMode: 'Alert'
    dnsSettings: { enableProxy: true }
  }
}

resource baseRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-06-01' = {
  parent: firewallPolicy
  name: 'DefaultRuleCollectionGroup'
  properties: {
    priority: 200
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name:               'AllowInternalRFC1918'
        priority:           100
        action: { type: 'Allow' }
        rules: [
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-Internal-RFC1918'
            protocols:            ['Any']
            sourceAddresses:      ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']
            destinationAddresses: ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']
            destinationPorts:     ['*']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-DNS'
            protocols:            ['UDP', 'TCP']
            sourceAddresses:      ['10.0.0.0/8']
            destinationAddresses: ['10.0.0.0/8']
            destinationPorts:     ['53']
          }
        ]
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Azure Firewall (standalone, in AzureFirewallSubnet)
// Private IP is statically assigned from the subnet range.
// ---------------------------------------------------------------------------
resource azureFirewall 'Microsoft.Network/azureFirewalls@2023-06-01' = {
  name: firewallName
  location: location
  tags: union(tags, { Function: 'Hub-Connectivity', Purpose: 'Azure-Firewall' })
  zones: ['1', '2', '3']
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: firewallSkuTier
    }
    firewallPolicy: { id: firewallPolicy.id }
    ipConfigurations: [
      {
        name: 'fw-ipconfig-01'
        properties: {
          publicIPAddress:  { id: pipFirewall.id }
          subnet:           { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureFirewallSubnet') }
          privateIPAddress: firewallPrivateIp
          privateIPAllocationMethod: 'Static'
        }
      }
    ]
  }
  dependsOn: [hubVnet]
}

// ---------------------------------------------------------------------------
// Active-Active VPN Gateway
// enableActiveActiveFeature = true requires two ipConfigurations and
// two BGP peering addresses. Each config uses a separate public IP.
// VpnGw1AZ SKU is zone-redundant and supports active-active + BGP.
// ---------------------------------------------------------------------------
resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2023-06-01' = {
  name: vpnGwName
  location: location
  tags: union(tags, { Function: 'Hub-Connectivity', Purpose: 'VPN-Gateway-AA' })
  properties: {
    gatewayType: 'Vpn'
    vpnType:     'RouteBased'
    sku: {
      name: vpnGwSku
      tier: vpnGwSku
    }
    enableActiveActiveFeature: true    // ACTIVE-ACTIVE
    enableBgp:                 true    // BGP required for active-active
    bgpSettings: {
      asn: bgpAsn
      // BGP peering IPs are auto-assigned per instance from GatewaySubnet
    }
    ipConfigurations: [
      {
        name: 'gwipconfig1'            // Instance 1
        properties: {
          publicIPAddress:            { id: pipVpnGw1.id }
          subnet:                     { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'GatewaySubnet') }
          privateIPAllocationMethod:  'Dynamic'
        }
      }
      {
        name: 'gwipconfig2'            // Instance 2 (active-active requires 2)
        properties: {
          publicIPAddress:            { id: pipVpnGw2.id }
          subnet:                     { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'GatewaySubnet') }
          privateIPAllocationMethod:  'Dynamic'
        }
      }
    ]
    vpnGatewayGeneration: 'Generation1'
  }
  dependsOn: [hubVnet]
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output hubVnetId           string = hubVnet.id
output hubVnetName         string = hubVnet.name
output firewallId          string = azureFirewall.id
output firewallName        string = azureFirewall.name
output firewallPrivateIp   string = firewallPrivateIp
output firewallPolicyId    string = firewallPolicy.id
output vpnGatewayId        string = vpnGateway.id
output vpnGatewayName      string = vpnGateway.name
output vpnGwPip1           string = pipVpnGw1.properties.ipAddress
output vpnGwPip2           string = pipVpnGw2.properties.ipAddress
output bastionSubnetId     string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureBastionSubnet')
output hubConnectivityType string = 'hub-azfw-vpngw'

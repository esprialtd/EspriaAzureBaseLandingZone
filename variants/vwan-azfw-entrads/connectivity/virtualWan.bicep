// =============================================================================
// variants/vwan-azfw/connectivity/virtualWan.bicep
// Azure Virtual WAN – global resource, deployed once in the primary region RG.
//
// vWAN is a global service but its metadata is stored in a nominated region.
// Espria standard: primary region (UK South) for the vWAN resource.
// All regional vWAN Hubs reference this single vWAN resource ID.
//
// SKU: Standard – required for Azure Firewall in hubs, ExpressRoute, VPN,
//      hub-to-hub transit, and branch-to-branch traffic.
//      Basic SKU only supports S2S VPN and has no Firewall support.
// =============================================================================

param location string
param environment string
param customerAbbreviation string
param tags object

var custAbbr = toUpper(customerAbbreviation)
var env      = environment

var vwanName = 'vwan-${env}-core-connectivity-${custAbbr}-01'

resource virtualWan 'Microsoft.Network/virtualWans@2023-06-01' = {
  name: vwanName
  location: location
  tags: union(tags, { Function: 'Hub-Connectivity', Purpose: 'Virtual-WAN' })
  properties: {
    type:                       'Standard'
    allowBranchToBranchTraffic: true
    allowVnetToVnetTraffic:     true
    disableVpnEncryption:       false
  }
}

output vwanId   string = virtualWan.id
output vwanName string = virtualWan.name

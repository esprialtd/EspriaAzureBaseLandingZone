// =============================================================================
// modules/connectivity/spokeToHubPeering.bicep
// Creates the HUB → SPOKE return peering for a given spoke VNet.
// Scope: the connectivity resource group (hub side).
//
// Why this is a separate module:
//   VNet peering requires TWO peering objects — one on each VNet.
//   The spoke → hub peering is created inside each spoke module
//   (identityVnet.bicep, managementVnet.bicep) because those modules
//   own the spoke VNet resource and have its ID at hand.
//   The hub → spoke return peering CANNOT be created in those same modules
//   because it must be scoped to the connectivity resource group, which is
//   a different scope to the identity/management resource groups those
//   modules deploy into. This module is called from main.bicep after both
//   sides exist, with dependsOn ensuring ordering.
// =============================================================================

@description('Name of the hub VNet (must already exist in this RG)')
param hubVnetName string

@description('Full resource ID of the spoke VNet')
param spokeVnetId string

@description('Short label for this spoke used in the peering name (e.g. identity, management)')

@description('Allow forwarded traffic from the spoke (required for NVA traffic flow)')
param allowForwardedTraffic bool = true

resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-06-01' = {
  name: '${hubVnetName}/link-to-${last(split(spokeVnetId, '/'))}'
  properties: {
    remoteVirtualNetwork:      { id: spokeVnetId }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic:     allowForwardedTraffic
    // Hub does not use remote gateway (Sophos XG on hub handles routing)
    allowGatewayTransit:       false
    useRemoteGateways:         false
  }
}

output peeringId   string = hubToSpokePeering.id
output peeringName string = hubToSpokePeering.name

// modules/connectivity/vnetPeering.bicep
param localVnetName          string
param remoteVnetId           string
param peeringName            string
param allowGatewayTransit    bool = false
param useRemoteGateways      bool = false
param allowForwardedTraffic  bool = true

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-06-01' = {
  name: '${localVnetName}/${peeringName}'
  properties: {
    remoteVirtualNetwork:      { id: remoteVnetId }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic:     allowForwardedTraffic
    allowGatewayTransit:       allowGatewayTransit
    useRemoteGateways:         useRemoteGateways
  }
}

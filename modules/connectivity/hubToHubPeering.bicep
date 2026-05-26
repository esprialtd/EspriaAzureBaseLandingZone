// =============================================================================
// modules/connectivity/hubToHubPeering.bicep
// Creates bidirectional VNet peering between primary and secondary hub VNets
// Scope: subscription (uses module scoping to reach both RGs)
// =============================================================================

targetScope = 'subscription'

param primaryRg         string
param secondaryRg       string
param primaryVnetName   string
param secondaryVnetName string
param primaryVnetId     string
param secondaryVnetId   string

// Primary → Secondary
module peerPriToSec 'vnetPeering.bicep' = {
  name: 'peer-pri-to-sec'
  scope: resourceGroup(primaryRg)
  params: {
    localVnetName:  primaryVnetName
    remoteVnetId:   secondaryVnetId
    peeringName:    'link-to-${secondaryVnetName}'
    allowGatewayTransit:  true
    useRemoteGateways:    false
    allowForwardedTraffic: true
  }
}

// Secondary → Primary
module peerSecToPri 'vnetPeering.bicep' = {
  name: 'peer-sec-to-pri'
  scope: resourceGroup(secondaryRg)
  params: {
    localVnetName:  secondaryVnetName
    remoteVnetId:   primaryVnetId
    peeringName:    'link-to-${primaryVnetName}'
    allowGatewayTransit:  false
    useRemoteGateways:    false
    allowForwardedTraffic: true
  }
}

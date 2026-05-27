// shared/util/regionCapabilities.bicep
targetScope = 'subscription'

@description('Azure region name (e.g. uksouth, ukwest)')
param region string

@description('Whether the deployment should try to use availability zones when supported')
param useAvailabilityZones bool = true

// Maintain a conservative allow-list for zone-capable regions you support.
// (You can expand over time.)
var zoneCapableRegions = [
  'uksouth'
  'westeurope'
  'northeurope'
  'eastus'
  'eastus2'
  'westus2'
  'westus3'
]

var supportsZones = contains(zoneCapableRegions, toLower(region))
var zoneEnabled = useAvailabilityZones && supportsZones

// Zonal set to use for resources that want "zone redundant" placement (PIP/Bastion etc.)
var zoneSetAll = [
  '1'
  '2'
  '3'
]

// For single-instance VMs you typically pin to a single zone (if enabled)
var zoneSetSingle = [
  '1'
]

// Disk SKU recommendation (see section 2)
output supportsZones bool = supportsZones
output zoneEnabled bool = zoneEnabled
output zonesAll array = zoneEnabled ? zoneSetAll : []
output zonesSingle array = zoneEnabled ? zoneSetSingle : []

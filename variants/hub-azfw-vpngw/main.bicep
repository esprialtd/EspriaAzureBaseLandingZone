// =============================================================================
// variants/hub-azfw-vpngw/main.bicep
// Espria Azure Landing Zone – Variant C: Hub-Spoke + Azure Firewall + Active-Active VPN GW
//
// Connectivity model : Hub-Spoke VNet (same as Sophos variant)
// Firewall           : Azure Firewall Premium (standalone in AzureFirewallSubnet)
// VPN                : Active-Active VPN Gateway (VpnGw1AZ, BGP enabled)
// Identity           : IaaS Active Directory Domain Services (shared module)
// Routing            : UDRs on spokes pointing 0.0.0.0/0 to Azure Firewall private IP
// Hub-to-Hub         : Explicit VNet peering (same as Sophos variant)
//
// Key differences from Sophos-NVA variant:
//   - AzureFirewallSubnet /26 in hub (mandatory name, no NSG)
//   - GatewaySubnet /27 NOW ACTIVE – VPN Gateway deployed here
//   - No NVALAN/NVAWAN subnets, no NVA VM
//   - nextHopIp for spokes = Azure Firewall static private IP (not NVA)
//   - Active-Active VPN GW = two PIPs, two instances, BGP
//   - Hub-to-Hub VNet peering still used (no vWAN)
// =============================================================================

targetScope = 'subscription'

// ---------------------------------------------------------------------------
// Customer Identity Parameters
// ---------------------------------------------------------------------------
@description('Customer full name')
param customerName string

@description('3–5 character abbreviation used in all resource names')
@maxLength(5)
param customerAbbreviation string

@description('Active Directory domain name (e.g. contoso.local)')
param customerDomainName string

// ---------------------------------------------------------------------------
// Region Parameters
// ---------------------------------------------------------------------------
@allowed([
  'australiacentral' 'australiacentral2' 'australiaeast' 'australiasoutheast'
  'brazilsouth' 'brazilsoutheast' 'canadacentral' 'canadaeast'
  'centralindia' 'centralus' 'eastasia' 'eastus' 'eastus2'
  'francecentral' 'francesouth' 'germanynorth' 'germanywestcentral'
  'israelcentral' 'italynorth' 'japaneast' 'japanwest'
  'jioindiacentral' 'jioindiawest' 'koreacentral' 'koreasouth'
  'mexicocentral' 'newzealandnorth' 'northcentralus' 'northeurope'
  'norwayeast' 'norwaywest' 'polandcentral' 'qatarcentral'
  'southafricanorth' 'southafricawest' 'southcentralus' 'southeastasia'
  'southindia' 'spaincentral' 'swedencentral' 'swedensouth'
  'switzerlandnorth' 'switzerlandwest' 'uaecentral' 'uaenorth'
  'uksouth' 'ukwest' 'westcentralus' 'westeurope' 'westindia'
  'westus' 'westus2' 'westus3'
])
param primaryRegion string = 'uksouth'

@allowed([
  'auto'
  'australiacentral' 'australiacentral2' 'australiaeast' 'australiasoutheast'
  'brazilsouth' 'brazilsoutheast' 'canadacentral' 'canadaeast'
  'centralindia' 'centralus' 'eastasia' 'eastus' 'eastus2'
  'francecentral' 'francesouth' 'germanynorth' 'germanywestcentral'
  'israelcentral' 'italynorth' 'japaneast' 'japanwest'
  'jioindiacentral' 'jioindiawest' 'koreacentral' 'koreasouth'
  'mexicocentral' 'newzealandnorth' 'northcentralus' 'northeurope'
  'norwayeast' 'norwaywest' 'polandcentral' 'qatarcentral'
  'southafricanorth' 'southafricawest' 'southcentralus' 'southeastasia'
  'southindia' 'spaincentral' 'swedencentral' 'swedensouth'
  'switzerlandnorth' 'switzerlandwest' 'uaecentral' 'uaenorth'
  'uksouth' 'ukwest' 'westcentralus' 'westeurope' 'westindia'
  'westus' 'westus2' 'westus3'
])
param secondaryRegion string = 'auto'

param deploySecondaryRegion bool = true

@allowed(['prod', 'dev', 'uat'])
param environment string = 'prod'

// ---------------------------------------------------------------------------
// Networking
// ---------------------------------------------------------------------------
@minValue(101)
@maxValue(199)
param primaryRegionSiteId int = 101

@minValue(101)
@maxValue(199)
param secondaryRegionSiteId int = 102

param onPremAddressPrefix string = '10.1.0.0/16'

// ---------------------------------------------------------------------------
// Azure Firewall and VPN Gateway
// ---------------------------------------------------------------------------
@allowed(['Premium', 'Standard'])
param firewallSkuTier string = 'Premium'

@allowed(['VpnGw1AZ', 'VpnGw2AZ', 'VpnGw3AZ', 'VpnGw1', 'VpnGw2', 'VpnGw3'])
param vpnGwSku string = 'VpnGw1AZ'

@description('BGP ASN for the Azure side of all VPN tunnels. Must not match on-premises ASN.')
param bgpAsn int = 65000

// ---------------------------------------------------------------------------
// Identity / VM Parameters
// ---------------------------------------------------------------------------
param adminUsername string

@secure()
param adminPassword string

param dcVmSize   string = 'Standard_D2s_v5'
param mgmtVmSize string = 'Standard_B2ms'

// ---------------------------------------------------------------------------
// Tagging
// ---------------------------------------------------------------------------
param createdBy string = 'Espria'
param managedBy string = 'Espria'

// ---------------------------------------------------------------------------
// Monitoring & Backup
// ---------------------------------------------------------------------------
param alertEmailAddress  string = 'alerts@espria.com'
param lawRetentionDays   int    = 90
param enableVmBackup     bool   = true
param enableNvaDiskBackup bool  = false   // No NVA in this variant
param enableAsrMgmtVm    bool   = true

// ---------------------------------------------------------------------------
// Region maps
// ---------------------------------------------------------------------------
var regionPairMap = {
  australiacentral: 'australiacentral2'  australiacentral2: 'australiacentral'
  australiaeast: 'australiasoutheast'    australiasoutheast: 'australiaeast'
  brazilsouth: 'southcentralus'          brazilsoutheast: 'brazilsouth'
  canadacentral: 'canadaeast'            canadaeast: 'canadacentral'
  centralindia: 'southindia'             centralus: 'eastus2'
  eastasia: 'southeastasia'              eastus: 'westus'
  eastus2: 'centralus'                   francecentral: 'francesouth'
  francesouth: 'francecentral'           germanynorth: 'germanywestcentral'
  germanywestcentral: 'germanynorth'     israelcentral: 'italynorth'
  italynorth: 'israelcentral'            japaneast: 'japanwest'
  japanwest: 'japaneast'                 jioindiacentral: 'jioindiawest'
  jioindiawest: 'jioindiacentral'        koreacentral: 'koreasouth'
  koreasouth: 'koreacentral'             mexicocentral: 'southcentralus'
  newzealandnorth: 'australiaeast'       northcentralus: 'southcentralus'
  northeurope: 'westeurope'              norwayeast: 'norwaywest'
  norwaywest: 'norwayeast'               polandcentral: 'germanywestcentral'
  qatarcentral: 'uaenorth'              southafricanorth: 'southafricawest'
  southafricawest: 'southafricanorth'    southcentralus: 'northcentralus'
  southeastasia: 'eastasia'              southindia: 'centralindia'
  spaincentral: 'francecentral'          swedencentral: 'swedensouth'
  swedensouth: 'swedencentral'           switzerlandnorth: 'switzerlandwest'
  switzerlandwest: 'switzerlandnorth'    uaecentral: 'uaenorth'
  uaenorth: 'uaecentral'                uksouth: 'ukwest'
  ukwest: 'uksouth'                      westcentralus: 'westus2'
  westeurope: 'northeurope'              westindia: 'southindia'
  westus: 'eastus'                       westus2: 'westcentralus'
  westus3: 'eastus'
}
var regionAbbrevMap = {
  australiacentral: 'ACL'  australiacentral2: 'AC2'  australiaeast: 'AEA'
  australiasoutheast: 'ASE'  brazilsouth: 'BRS'  brazilsoutheast: 'BSE'
  canadacentral: 'CAC'  canadaeast: 'CAE'  centralindia: 'CIN'
  centralus: 'CUS'  eastasia: 'EAP'  eastus: 'EUS'  eastus2: 'EU2'
  francecentral: 'FRC'  francesouth: 'FRS'  germanynorth: 'GNO'
  germanywestcentral: 'GWC'  israelcentral: 'ILC'  italynorth: 'ITN'
  japaneast: 'JPE'  japanwest: 'JPW'  jioindiacentral: 'JIC'
  jioindiawest: 'JIW'  koreacentral: 'KRC'  koreasouth: 'KRS'
  mexicocentral: 'MXC'  newzealandnorth: 'NZN'  northcentralus: 'NCU'
  northeurope: 'NEU'  norwayeast: 'NOE'  norwaywest: 'NOW'
  polandcentral: 'POC'  qatarcentral: 'QAC'  southafricanorth: 'SAN'
  southafricawest: 'SAW'  southcentralus: 'SCU'  southeastasia: 'SEA'
  southindia: 'SIN'  spaincentral: 'SPC'  swedencentral: 'SWC'
  swedensouth: 'SWS'  switzerlandnorth: 'CHN'  switzerlandwest: 'CHW'
  uaecentral: 'UAC'  uaenorth: 'UAN'  uksouth: 'UKS'  ukwest: 'UKW'
  westcentralus: 'WCU'  westeurope: 'WEU'  westindia: 'WIN'
  westus: 'WUS'  westus2: 'WU2'  westus3: 'WU3'
}

var resolvedSecondaryRegion = secondaryRegion == 'auto' ? regionPairMap[primaryRegion] : secondaryRegion
var custAbbr   = toUpper(customerAbbreviation)
var custAbbrLo = toLower(customerAbbreviation)
var env        = environment
var priAbbr    = regionAbbrevMap[primaryRegion]
var secAbbr    = regionAbbrevMap[resolvedSecondaryRegion]
var priOctet   = primaryRegionSiteId
var secOctet   = secondaryRegionSiteId

var priConnectivityPrefix = '10.${priOctet}.0.0/21'
var priIdentityPrefix     = '10.${priOctet}.8.0/22'
var priManagementPrefix   = '10.${priOctet}.248.0/21'
var secConnectivityPrefix = '10.${secOctet}.0.0/21'
var secIdentityPrefix     = '10.${secOctet}.8.0/22'
var secManagementPrefix   = '10.${secOctet}.248.0/21'

var rgPriConnectivity = 'rg-${env}-core-connectivity-${custAbbr}-${primaryRegion}-01'
var rgPriIdentity     = 'rg-${env}-core-identity-${custAbbr}-${primaryRegion}-01'
var rgPriManagement   = 'rg-${env}-core-management-${custAbbr}-${primaryRegion}-01'
var rgSecConnectivity = 'rg-${env}-core-connectivity-${custAbbr}-${resolvedSecondaryRegion}-01'
var rgSecIdentity     = 'rg-${env}-core-identity-${custAbbr}-${resolvedSecondaryRegion}-01'
var rgSecManagement   = 'rg-${env}-core-management-${custAbbr}-${resolvedSecondaryRegion}-01'

var vnetPriConnectivity = 'vnet-${env}-core-connectivity-${custAbbr}-${primaryRegion}-01'
var vnetPriIdentity     = 'vnet-${env}-core-identity-${custAbbr}-${primaryRegion}-01'
var vnetPriManagement   = 'vnet-${env}-core-management-${custAbbr}-${primaryRegion}-01'
var vnetSecConnectivity = 'vnet-${env}-core-connectivity-${custAbbr}-${resolvedSecondaryRegion}-01'
var vnetSecIdentity     = 'vnet-${env}-core-identity-${custAbbr}-${resolvedSecondaryRegion}-01'
var vnetSecManagement   = 'vnet-${env}-core-management-${custAbbr}-${resolvedSecondaryRegion}-01'

var commonTags = {
  CreatedBy:   createdBy
  ManagedBy:   managedBy
  Environment: env
  Customer:    customerName
  DeployedBy:  'Espria-LZ-Bicep'
  Variant:     'hub-azfw-vpngw'
}

// ===========================================================================
// MANAGEMENT GROUPS + RESOURCE GROUPS (shared)
// ===========================================================================
module managementGroups '../../shared/governance/managementGroups.bicep' = {
  name: 'deploy-managementGroups'
  params: { customerName: customerName, customerAbbreviation: custAbbr }
}

module rgsPrimary '../../shared/governance/resourceGroups.bicep' = {
  name: 'deploy-rgs-primary'
  params: {
    location: primaryRegion, customerAbbreviation: custAbbr
    region: primaryRegion, environment: env, tags: commonTags
  }
}

module rgsSecondary '../../shared/governance/resourceGroups.bicep' = if (deploySecondaryRegion) {
  name: 'deploy-rgs-secondary'
  params: {
    location: resolvedSecondaryRegion, customerAbbreviation: custAbbr
    region: resolvedSecondaryRegion, environment: env, tags: commonTags
  }
}

// ===========================================================================
// CONNECTIVITY – Hub VNet + Azure Firewall + Active-Active VPN Gateway
// ===========================================================================
module priConnectivity './connectivity/hubConnectivityAzfw.bicep' = {
  name: 'deploy-pri-connectivity'
  scope: resourceGroup(rgPriConnectivity)
  dependsOn: [rgsPrimary]
  params: {
    location: primaryRegion, environment: env
    customerAbbreviation: custAbbr, regionAbbreviation: priAbbr
    vnetName: vnetPriConnectivity, addressPrefix: priConnectivityPrefix
    siteOctet: priOctet, onPremAddressPrefix: onPremAddressPrefix
    firewallSkuTier: firewallSkuTier, vpnGwSku: vpnGwSku, bgpAsn: bgpAsn
    tags: commonTags
  }
}

module secConnectivity './connectivity/hubConnectivityAzfw.bicep' = if (deploySecondaryRegion) {
  name: 'deploy-sec-connectivity'
  scope: resourceGroup(rgSecConnectivity)
  dependsOn: [rgsSecondary]
  params: {
    location: resolvedSecondaryRegion, environment: env
    customerAbbreviation: custAbbr, regionAbbreviation: secAbbr
    vnetName: vnetSecConnectivity, addressPrefix: secConnectivityPrefix
    siteOctet: secOctet, onPremAddressPrefix: onPremAddressPrefix
    firewallSkuTier: firewallSkuTier, vpnGwSku: vpnGwSku, bgpAsn: bgpAsn
    tags: commonTags
  }
}

// ===========================================================================
// IDENTITY (shared module – nextHopIp = Azure Firewall private IP)
// ===========================================================================
module priIdentity '../../shared/identity/adds/identityVnet.bicep' = {
  name: 'deploy-pri-identity'
  scope: resourceGroup(rgPriIdentity)
  dependsOn: [rgsPrimary, priConnectivity]
  params: {
    location: primaryRegion, environment: env
    customerAbbreviation: custAbbr, regionAbbreviation: priAbbr
    vnetName: vnetPriIdentity, addressPrefix: priIdentityPrefix, siteOctet: priOctet
    hubVnetId: priConnectivity.outputs.hubVnetId
    nextHopIp: priConnectivity.outputs.firewallPrivateIp
    onPremAddressPrefix: onPremAddressPrefix
    adminUsername: adminUsername, adminPassword: adminPassword
    dcCount: 2, dcVmSize: dcVmSize, customerDomainName: customerDomainName
    tags: commonTags
  }
}

module priManagement '../../shared/management/managementVnet.bicep' = {
  name: 'deploy-pri-management'
  scope: resourceGroup(rgPriManagement)
  dependsOn: [rgsPrimary, priConnectivity]
  params: {
    location: primaryRegion, environment: env
    customerAbbreviation: custAbbr, regionAbbreviation: priAbbr
    vnetName: vnetPriManagement, addressPrefix: priManagementPrefix, siteOctet: priOctet
    hubVnetId: priConnectivity.outputs.hubVnetId
    bastionSubnetId: priConnectivity.outputs.bastionSubnetId
    nextHopIp: priConnectivity.outputs.firewallPrivateIp
    onPremAddressPrefix: onPremAddressPrefix
    adminUsername: adminUsername, adminPassword: adminPassword
    mgmtVmSize: mgmtVmSize, tags: commonTags
  }
}

module secIdentity '../../shared/identity/adds/identityVnet.bicep' = if (deploySecondaryRegion) {
  name: 'deploy-sec-identity'
  scope: resourceGroup(rgSecIdentity)
  dependsOn: [rgsSecondary, secConnectivity]
  params: {
    location: resolvedSecondaryRegion, environment: env
    customerAbbreviation: custAbbr, regionAbbreviation: secAbbr
    vnetName: vnetSecIdentity, addressPrefix: secIdentityPrefix, siteOctet: secOctet
    hubVnetId: deploySecondaryRegion ? secConnectivity.outputs.hubVnetId : ''
    nextHopIp: deploySecondaryRegion ? secConnectivity.outputs.firewallPrivateIp : ''
    onPremAddressPrefix: onPremAddressPrefix
    adminUsername: adminUsername, adminPassword: adminPassword
    dcCount: 1, dcVmSize: dcVmSize, customerDomainName: customerDomainName
    tags: commonTags
  }
}

module secManagement '../../shared/management/managementVnet.bicep' = if (deploySecondaryRegion) {
  name: 'deploy-sec-management'
  scope: resourceGroup(rgSecManagement)
  dependsOn: [rgsSecondary, secConnectivity]
  params: {
    location: resolvedSecondaryRegion, environment: env
    customerAbbreviation: custAbbr, regionAbbreviation: secAbbr
    vnetName: vnetSecManagement, addressPrefix: secManagementPrefix, siteOctet: secOctet
    hubVnetId: deploySecondaryRegion ? secConnectivity.outputs.hubVnetId : ''
    bastionSubnetId: deploySecondaryRegion ? secConnectivity.outputs.bastionSubnetId : ''
    nextHopIp: deploySecondaryRegion ? secConnectivity.outputs.firewallPrivateIp : ''
    onPremAddressPrefix: onPremAddressPrefix
    adminUsername: adminUsername, adminPassword: adminPassword
    mgmtVmSize: mgmtVmSize, tags: commonTags
  }
}

// ===========================================================================
// VNet PEERING (hub-spoke model, same as Sophos variant)
// ===========================================================================
module priHubToIdentity './connectivity/spokeToHubPeering.bicep' = {
  name: 'deploy-pri-hub-to-identity'
  scope: resourceGroup(rgPriConnectivity)
  dependsOn: [priConnectivity, priIdentity]
  params: {
    hubVnetName: vnetPriConnectivity, spokeVnetId: priIdentity.outputs.identityVnetId
    spokeLabel: 'identity', allowForwardedTraffic: true
  }
}

module priHubToManagement './connectivity/spokeToHubPeering.bicep' = {
  name: 'deploy-pri-hub-to-management'
  scope: resourceGroup(rgPriConnectivity)
  dependsOn: [priConnectivity, priManagement]
  params: {
    hubVnetName: vnetPriConnectivity, spokeVnetId: priManagement.outputs.mgmtVnetId
    spokeLabel: 'management', allowForwardedTraffic: true
  }
}

module secHubToIdentity './connectivity/spokeToHubPeering.bicep' = if (deploySecondaryRegion) {
  name: 'deploy-sec-hub-to-identity'
  scope: resourceGroup(rgSecConnectivity)
  dependsOn: [secConnectivity, secIdentity]
  params: {
    hubVnetName: vnetSecConnectivity
    spokeVnetId: deploySecondaryRegion ? secIdentity.outputs.identityVnetId : ''
    spokeLabel: 'identity', allowForwardedTraffic: true
  }
}

module secHubToManagement './connectivity/spokeToHubPeering.bicep' = if (deploySecondaryRegion) {
  name: 'deploy-sec-hub-to-management'
  scope: resourceGroup(rgSecConnectivity)
  dependsOn: [secConnectivity, secManagement]
  params: {
    hubVnetName: vnetSecConnectivity
    spokeVnetId: deploySecondaryRegion ? secManagement.outputs.mgmtVnetId : ''
    spokeLabel: 'management', allowForwardedTraffic: true
  }
}

module hubToHub './connectivity/hubToHubPeering.bicep' = if (deploySecondaryRegion) {
  name: 'deploy-hub-to-hub-peering'
  dependsOn: [priConnectivity, secConnectivity]
  params: {
    primaryHubVnetId:    priConnectivity.outputs.hubVnetId
    secondaryHubVnetId:  deploySecondaryRegion ? secConnectivity.outputs.hubVnetId : ''
    primaryRgName:       rgPriConnectivity
    secondaryRgName:     rgSecConnectivity
  }
}

// ===========================================================================
// MONITORING + GOVERNANCE + BACKUP (all shared – identical to other variants)
// ===========================================================================
module monitoring '../../shared/monitoring/centralMonitoring.bicep' = {
  name: 'deploy-monitoring'
  scope: resourceGroup(rgPriManagement)
  dependsOn: [priManagement, priIdentity, priConnectivity]
  params: {
    location: primaryRegion, environment: env
    customerAbbreviation: custAbbr, alertEmailAddress: alertEmailAddress
    retentionDays: lawRetentionDays, tags: commonTags
    vmInsightsVms: concat(
      [for i in range(0, 2): { id: priIdentity.outputs.dcVmIds[i], location: primaryRegion }],
      [{ id: priManagement.outputs.mgmtVmId, location: primaryRegion }]
    )
    vnetDiagnosticTargets: [
      { id: priConnectivity.outputs.hubVnetId, location: primaryRegion }
      { id: priIdentity.outputs.identityVnetId, location: primaryRegion }
      { id: priManagement.outputs.mgmtVnetId, location: primaryRegion }
    ]
  }
}

module governancePolicies '../../shared/governance/policies.bicep' = {
  name: 'deploy-governance-policies'
  dependsOn: [monitoring]
  params: {
    environment: env, customerAbbreviation: custAbbr
    primaryRegion: primaryRegion, secondaryRegion: resolvedSecondaryRegion
    lawResourceId: monitoring.outputs.lawId, dcrResourceId: monitoring.outputs.dcrId
  }
}

module backupIdentityPrimary '../../shared/backup/backupAndRecovery.bicep' = if (enableVmBackup) {
  name: 'deploy-backup-identity-primary'
  scope: resourceGroup(rgPriIdentity)
  dependsOn: [priIdentity]
  params: {
    location: primaryRegion, environment: env
    customerAbbreviation: custAbbr, region: primaryRegion
    resourceGroupContext: 'identity', tags: commonTags
    vmBackupTargets: [for i in range(0, 2): {
      vmId: priIdentity.outputs.dcVmIds[i]
      vmName: priIdentity.outputs.dcVmNames[i]
      rgName: rgPriIdentity
    }]
    diskBackupTargets: []
  }
}

module backupManagementPrimary '../../shared/backup/backupAndRecovery.bicep' = if (enableVmBackup) {
  name: 'deploy-backup-management-primary'
  scope: resourceGroup(rgPriManagement)
  dependsOn: [priManagement]
  params: {
    location: primaryRegion, environment: env
    customerAbbreviation: custAbbr, region: primaryRegion
    resourceGroupContext: 'management', tags: commonTags
    vmBackupTargets: [{
      vmId: priManagement.outputs.mgmtVmId
      vmName: priManagement.outputs.mgmtVmName
      rgName: rgPriManagement
    }]
    diskBackupTargets: []
  }
}

module asrCacheStorage '../../shared/backup/asrCacheStorage.bicep' = if (enableAsrMgmtVm && deploySecondaryRegion) {
  name: 'deploy-asr-cache-storage'
  scope: resourceGroup(rgPriConnectivity)
  dependsOn: [rgsPrimary]
  params: {
    location: primaryRegion, environment: env
    customerAbbreviation: custAbbrLo, region: primaryRegion, tags: commonTags
  }
}

module asrMgmtVm '../../shared/backup/asrReplication.bicep' = if (enableAsrMgmtVm && deploySecondaryRegion) {
  name: 'deploy-asr-mgmt-vm'
  scope: resourceGroup(rgSecManagement)
  dependsOn: [priManagement, secManagement, asrCacheStorage]
  params: {
    location: resolvedSecondaryRegion, environment: env
    customerAbbreviation: custAbbr, region: resolvedSecondaryRegion
    primaryRegion: primaryRegion, tags: commonTags
    sourceVmId: priManagement.outputs.mgmtVmId
    sourceVmName: priManagement.outputs.mgmtVmName
    sourceVmOsDiskId: priManagement.outputs.mgmtVmOsDiskId
    sourceVmLocation: primaryRegion
    sourceMgmtVnetId: priManagement.outputs.mgmtVnetId
    targetMgmtVnetId: deploySecondaryRegion ? secManagement.outputs.mgmtVnetId : ''
    cacheStorageAccountId: (enableAsrMgmtVm && deploySecondaryRegion) ? asrCacheStorage.outputs.storageAccountId : ''
  }
}

// ===========================================================================
// OUTPUTS
// ===========================================================================
output primaryFirewallId        string = priConnectivity.outputs.firewallId
output primaryFirewallPrivateIp string = priConnectivity.outputs.firewallPrivateIp
output primaryVpnGatewayId      string = priConnectivity.outputs.vpnGatewayId
output primaryVpnGwPip1         string = priConnectivity.outputs.vpnGwPip1
output primaryVpnGwPip2         string = priConnectivity.outputs.vpnGwPip2
output lawId                    string = monitoring.outputs.lawId
output actionGroupId            string = monitoring.outputs.actionGroupId

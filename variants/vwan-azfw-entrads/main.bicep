// =============================================================================
// variants/vwan-azfw/main.bicep
// Espria Azure Landing Zone – Variant B: vWAN + Azure Firewall
//
// Connectivity model : Azure Virtual WAN (Standard) + Secured Virtual Hubs
// Firewall           : Azure Firewall Premium (hub-injected, no AzureFirewallSubnet)
// Identity           : IaaS Active Directory Domain Services (shared module)
// Routing            : vWAN Routing Intent (replaces UDRs on spokes)
// Hub-to-Hub         : Automatic via vWAN global transit (no explicit peering)
//
// Key architectural difference from Sophos-NVA variant:
//   - No VNet hub – vWAN Hub manages routing natively
//   - No VNet peering – hubVirtualNetworkConnections used instead
//   - No UDRs on spokes – vWAN routing intent injects default routes
//   - Azure Firewall is deployed inside the vWAN hub (Secured Virtual Hub)
//   - vWAN is a global resource; hubs are regional
//   - Spoke VNets exist outside the vWAN hub and connect to it
// =============================================================================

targetScope = 'subscription'

// ---------------------------------------------------------------------------
// Customer Identity Parameters (same as all variants)
// ---------------------------------------------------------------------------
@description('Customer full name')
param customerName string

@description('3–5 character abbreviation used in all resource names')
@maxLength(5)
param customerAbbreviation string

@description('Entra Domain Services managed domain name. Must be routable (e.g. aadds.contoso.com). .local is not supported.')
param customerDomainName string

@description('Entra DS SKU. Enterprise required for replica sets (secondary region). Standard for primary-only.')
@allowed(['Enterprise','Standard','Premium'])
param entraDsSku string = 'Enterprise'

@description('Enable Secure LDAP on the managed domain. Certificate must be configured post-deployment.')
param enableSecureLdap bool = false

// ---------------------------------------------------------------------------
// Region Parameters
// ---------------------------------------------------------------------------
@allowed([
  'auto'
 // 'australiacentral'
 // 'australiacentral2'
 // 'australiaeast'
 // 'australiasoutheast'
 // 'brazilsouth'
 // 'brazilsoutheast'
  'canadacentral'
  'canadaeast'
 // 'centralindia'
  'centralus'
 // 'eastasia'
  'eastus'
  'eastus2'
  'francecentral'
  'francesouth'
  'germanynorth'
  'germanywestcentral'
 // 'israelcentral'
 // 'italynorth'
 // 'japaneast'
 // 'japanwest'
 // 'jioindiacentral'
 // 'jioindiawest'
 // 'koreacentral'
 // 'koreasouth'
 // 'mexicocentral'
 // 'newzealandnorth'
  'northcentralus'
  'northeurope'
 // 'norwayeast'
 // 'norwaywest'
 // 'polandcentral'
  'qatarcentral'
 // 'southafricanorth'
 // 'southafricawest'
 // 'southcentralus'
 // 'southeastasia'
 // 'southindia'
 // 'spaincentral'
 // 'swedencentral'
 // 'swedensouth'
 // 'switzerlandnorth'
 // 'switzerlandwest'
  'uaecentral'
  'uaenorth'
  'uksouth'
  'ukwest'
 // 'westcentralus'
  'westeurope'
 // 'westindia'
  'westus'
  'westus2'
  'westus3'
])
param primaryRegion string = 'uksouth'

@allowed([
  'auto'
 // 'australiacentral'
 // 'australiacentral2'
 // 'australiaeast'
 // 'australiasoutheast'
 // 'brazilsouth'
 // 'brazilsoutheast'
  'canadacentral'
  'canadaeast'
 // 'centralindia'
  'centralus'
 // 'eastasia'
  'eastus'
  'eastus2'
  'francecentral'
  'francesouth'
  'germanynorth'
  'germanywestcentral'
 // 'israelcentral'
 // 'italynorth'
 // 'japaneast'
 // 'japanwest'
 // 'jioindiacentral'
 // 'jioindiawest'
 // 'koreacentral'
 // 'koreasouth'
 // 'mexicocentral'
 // 'newzealandnorth'
  'northcentralus'
  'northeurope'
 // 'norwayeast'
 // 'norwaywest'
 // 'polandcentral'
  'qatarcentral'
 // 'southafricanorth'
 // 'southafricawest'
 // 'southcentralus'
 // 'southeastasia'
 // 'southindia'
 // 'spaincentral'
 // 'swedencentral'
 // 'swedensouth'
 // 'switzerlandnorth'
 // 'switzerlandwest'
  'uaecentral'
  'uaenorth'
  'uksouth'
  'ukwest'
 // 'westcentralus'
  'westeurope'
 // 'westindia'
  'westus'
  'westus2'
  'westus3'
])
param secondaryRegion string = 'auto'

param deploySecondaryRegion bool = true

@allowed(['prod', 'dev', 'uat'])
param environment string = 'prod'

//---------------------------------------------------------------------------
// Region Zone and Disk Redundancy Parameters
//---------------------------------------------------------------------------

@description('Attempt to use availability zones where supported')
param useAvailabilityZones bool = true

@description('Prefer ZRS managed disks where supported (non-ASR workloads).')
param preferZrsDisks bool = true

// ---------------------------------------------------------------------------
// Networking
// ---------------------------------------------------------------------------
@description('Primary region site ID (101–199). Used as 2nd octet of spoke 10.x.0.0/16 address spaces.')
@minValue(101)
@maxValue(199)
param primaryRegionSiteId int = 101

@description('Secondary region site ID.')
@minValue(101)
@maxValue(199)
param secondaryRegionSiteId int = 102

@description('vWAN Hub address prefix for the primary region. Defaults to 10.{primaryRegionSiteId}.0.0/23 — the same block the connectivity VNet occupies in hub-spoke variants, since vWAN replaces that VNet. Must not overlap with spoke VNets (identity .8.0/22, management .248.0/21). Leave empty to use the auto-derived default.')
param primaryHubPrefix string = ''

@description('vWAN Hub address prefix for the secondary region. Defaults to 10.{secondaryRegionSiteId}.0.0/23. Leave empty to use the auto-derived default.')
param secondaryHubPrefix string = ''

@description('Deploy a vWAN VPN Gateway in each hub. Adds ~30 minutes to provisioning time. Uses Microsoft.Network/vpnGateways (vWAN-native type), not a standalone VPN Gateway.')
param deployVpnGateway bool = false

@description('vWAN VPN Gateway scale unit. 1 = 500 Mbps aggregate (active-active pair).')
@minValue(1)
@maxValue(20)
param vpnGwScaleUnit int = 1

@allowed(['adds', 'entrads'])
@description('Identity type for firewall rule selection. ENTRADS variant uses "entrads".')
param identityType string = 'entrads'

@description('On-premises address prefix (used in firewall rules)')
param onPremAddressPrefix string = '10.1.0.0/16'

// ---------------------------------------------------------------------------
// Azure Firewall
// ---------------------------------------------------------------------------
@description('Azure Firewall SKU tier. Premium recommended for IDPS and TLS inspection.')
@allowed(['Premium', 'Standard'])
param firewallSkuTier string = 'Premium'

// ---------------------------------------------------------------------------
// Identity / VM Parameters
// ---------------------------------------------------------------------------
@description('Admin username for all VMs (DCs, management VM)')
param adminUsername string = 'esprialocaladmin'

@secure()
@description('Admin password for all VMs – must meet Azure complexity requirements (12+ chars, upper, lower, number, symbol)')
param adminPassword string

@description('Domain Controller VM size')
@allowed([
  'Standard_B2ms'
  'Standard_B4ms'
  'Standard_D2s_v5'
  'Standard_D4s_v5'
  'Standard_D2s_v5'
  'Standard_D4s_v5'
  'Standard_D2ds_v5'
  'Standard_D4ds_v5'
  'Standard_D2ads_v5'
  'Standard_D4ads_v5'
  'Standard_D2ls_v5'
  'Standard_D4ls_v5'
])
param dcVmSize   string = 'Standard_D2s_v5'

@description('Management jump VM size')
@allowed([
  'Standard_B2ms'
  'Standard_B4ms'
  'Standard_D2s_v5'
  'Standard_D4s_v5'
  'Standard_D2s_v5'
  'Standard_D4s_v5'
  'Standard_D2ds_v5'
  'Standard_D4ds_v5'
  'Standard_D2ads_v5'
  'Standard_D4ads_v5'
  'Standard_D2ls_v5'
  'Standard_D4ls_v5'
])
param mgmtVmSize string = 'Standard_D2s_v5'

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
// Region maps (identical to all variants – centralised in shared would require
// a shared variables bicep; duplicated here for self-contained main.bicep)
// ---------------------------------------------------------------------------
var regionPairMap = {
  australiacentral: 'australiacentral2'
  australiacentral2: 'australiacentral'
  australiaeast: 'australiasoutheast'
  australiasoutheast: 'australiaeast'
  brazilsouth: 'southcentralus'
  brazilsoutheast: 'brazilsouth'
  canadacentral: 'canadaeast'
  canadaeast: 'canadacentral'
  centralindia: 'southindia'
  centralus: 'eastus2'
  eastasia: 'southeastasia'
  eastus: 'westus'
  eastus2: 'centralus'
  francecentral: 'francesouth'
  francesouth: 'francecentral'
  germanynorth: 'germanywestcentral'
  germanywestcentral: 'germanynorth'
  israelcentral: 'italynorth'
  italynorth: 'israelcentral'
  japaneast: 'japanwest'
  japanwest: 'japaneast'
  jioindiacentral: 'jioindiawest'
  jioindiawest: 'jioindiacentral'
  koreacentral: 'koreasouth'
  koreasouth: 'koreacentral'
  mexicocentral: 'southcentralus'
  newzealandnorth: 'australiaeast'
  northcentralus: 'southcentralus'
  northeurope: 'westeurope'
  norwayeast: 'norwaywest'
  norwaywest: 'norwayeast'
  polandcentral: 'germanywestcentral'
  qatarcentral: 'uaenorth'
  southafricanorth: 'southafricawest'
  southafricawest: 'southafricanorth'
  southcentralus: 'northcentralus'
  southeastasia: 'eastasia'
  southindia: 'centralindia'
  spaincentral: 'francecentral'
  swedencentral: 'swedensouth'
  swedensouth: 'swedencentral'
  switzerlandnorth: 'switzerlandwest'
  switzerlandwest: 'switzerlandnorth'
  uaecentral: 'uaenorth'
  uaenorth: 'uaecentral'
  uksouth: 'ukwest'
  ukwest: 'uksouth'
  westcentralus: 'westus2'
  westeurope: 'northeurope'
  westindia: 'southindia'
  westus: 'eastus'
  westus2: 'westcentralus'
  westus3: 'eastus'
}
var regionAbbrevMap = {
  australiacentral: 'ACL'
  australiacentral2: 'AC2'
  australiaeast: 'AEA'
  australiasoutheast: 'ASE'
  brazilsouth: 'BRS'
  brazilsoutheast: 'BSE'
  canadacentral: 'CAC'
  canadaeast: 'CAE'
  centralindia: 'CIN'
  centralus: 'CUS'
  eastasia: 'EAP'
  eastus: 'EUS'
  eastus2: 'EU2'
  francecentral: 'FRC'
  francesouth: 'FRS'
  germanynorth: 'GNO'
  germanywestcentral: 'GWC'
  israelcentral: 'ILC'
  italynorth: 'ITN'
  japaneast: 'JPE'
  japanwest: 'JPW'
  jioindiacentral: 'JIC'
  jioindiawest: 'JIW'
  koreacentral: 'KRC'
  koreasouth: 'KRS'
  mexicocentral: 'MXC'
  newzealandnorth: 'NZN'
  northcentralus: 'NCU'
  northeurope: 'NEU'
  norwayeast: 'NOE'
  norwaywest: 'NOW'
  polandcentral: 'POC'
  qatarcentral: 'QAC'
  southafricanorth: 'SAN'
  southafricawest: 'SAW'
  southcentralus: 'SCU'
  southeastasia: 'SEA'
  southindia: 'SIN'
  spaincentral: 'SPC'
  swedencentral: 'SWC'
  swedensouth: 'SWS'
  switzerlandnorth: 'CHN'
  switzerlandwest: 'CHW'
  uaecentral: 'UAC'
  uaenorth: 'UAN'
  uksouth: 'UKS'
  ukwest: 'UKW'
  westcentralus: 'WCU'
  westeurope: 'WEU'
  westindia: 'WIN'
  westus: 'WUS'
  westus2: 'WU2'
  westus3: 'WU3'
}

var resolvedSecondaryRegion = secondaryRegion == 'auto' ? regionPairMap[primaryRegion] : secondaryRegion
var custAbbr   = toUpper(customerAbbreviation)
var custAbbrLo = toLower(customerAbbreviation)
var env        = environment
var priAbbr    = regionAbbrevMap[primaryRegion]
var secAbbr    = regionAbbrevMap[resolvedSecondaryRegion]
var priOctet   = primaryRegionSiteId
var secOctet   = secondaryRegionSiteId

// vWAN Hub prefixes: default to 10.{siteId}.0.0/23 (same block as connectivity
// VNet in hub-spoke variants — clean reuse since vWAN replaces that VNet).
// An explicit override can be passed via the primaryHubPrefix/secondaryHubPrefix params.
var resolvedPrimaryHubPrefix   = empty(primaryHubPrefix)   ? '10.${priOctet}.0.0/23' : primaryHubPrefix
var resolvedSecondaryHubPrefix = empty(secondaryHubPrefix) ? '10.${secOctet}.0.0/23' : secondaryHubPrefix

// Address spaces
var priIdentityPrefix  = '10.${priOctet}.8.0/22'
var priManagementPrefix = '10.${priOctet}.248.0/21'
var secIdentityPrefix  = '10.${secOctet}.8.0/22'
var secManagementPrefix = '10.${secOctet}.248.0/21'

// Resource Group names
var rgPriConnectivity = 'rg-${env}-core-connectivity-${custAbbr}-${primaryRegion}-01'
var rgPriIdentity     = 'rg-${env}-core-identity-${custAbbr}-${primaryRegion}-01'
var rgPriManagement   = 'rg-${env}-core-management-${custAbbr}-${primaryRegion}-01'
var rgSecConnectivity = 'rg-${env}-core-connectivity-${custAbbr}-${resolvedSecondaryRegion}-01'
var rgSecIdentity     = 'rg-${env}-core-identity-${custAbbr}-${resolvedSecondaryRegion}-01'
var rgSecManagement   = 'rg-${env}-core-management-${custAbbr}-${resolvedSecondaryRegion}-01'

// VNet names (spoke VNets – same naming as hub-spoke variant for consistency)
var vnetPriIdentity   = 'vnet-${env}-core-identity-${custAbbr}-${primaryRegion}-01'
var vnetPriManagement = 'vnet-${env}-core-management-${custAbbr}-${primaryRegion}-01'
var vnetSecIdentity   = 'vnet-${env}-core-identity-${custAbbr}-${resolvedSecondaryRegion}-01'
var vnetSecManagement = 'vnet-${env}-core-management-${custAbbr}-${resolvedSecondaryRegion}-01'

// DC static IPs
var priDc1Ip = '10.${priOctet}.8.11'
var priDc2Ip = '10.${priOctet}.8.12'
var secDc1Ip = '10.${secOctet}.8.11'

var commonTags = {
  CreatedBy:   createdBy
  ManagedBy:   managedBy
  Environment: env
  Customer:    customerName
  DeployedBy:  'Espria-LZ-Bicep'
  Variant:     'vwan-azfw-entrads'
}

// Pre-computed VM lists for monitoring (Entra DS has no DC VMs)
var priMgmtVmInsightsList = [{ id: priManagement.outputs.mgmtVmId, location: primaryRegion }]
var priAllVmInsightsList  = priMgmtVmInsightsList

// ===========================================================================
// MANAGEMENT GROUPS (shared)
// ===========================================================================
module managementGroups '../../shared/governance/managementGroups.bicep' = {
  name:  'deploy-managementGroups'
  scope: tenant()
  params: {
    customerName:         customerName
    customerAbbreviation: custAbbr
  }
}

// ===========================================================================
// RESOURCE GROUPS
// ===========================================================================
module rgsPrimary '../../shared/governance/resourceGroups.bicep' = {
  name: 'deploy-rgs-primary'
  params: {
    location:             primaryRegion
    customerAbbreviation: custAbbr
    region:               primaryRegion
    environment:          env
    tags:                 commonTags
  }
}

module rgsSecondary '../../shared/governance/resourceGroups.bicep' = if (deploySecondaryRegion) {
  name: 'deploy-rgs-secondary'
  params: {
    location:             resolvedSecondaryRegion
    customerAbbreviation: custAbbr
    region:               resolvedSecondaryRegion
    environment:          env
    tags:                 commonTags
  }
}

//---------------------------------------------------------------------------
// Region Zone and Disk Capabilities
//---------------------------------------------------------------------------

module priCaps '../../shared/util/regionCapabilities.bicep' = {
  name: 'caps-primary'
  params: {
    region: primaryRegion
    useAvailabilityZones: useAvailabilityZones
  }
}

module secCaps '../../shared/util/regionCapabilities.bicep' = if (deploySecondaryRegion) {
  name: 'caps-secondary'
  params: {
    region: resolvedSecondaryRegion
    useAvailabilityZones: useAvailabilityZones
  }
}

// Disk SKU decisions:
var preferredDiskSkuPrimary = (preferZrsDisks && priCaps.outputs.zoneEnabled) ? 'Premium_ZRS' : 'Premium_LRS'
var preferredDiskSkuSecondary = (preferZrsDisks && deploySecondaryRegion && secCaps.outputs.zoneEnabled) ? 'Premium_ZRS' : 'Premium_LRS'

// ASR constraint (Management VM only in your design):
// If ASR enabled and secondary not zone-capable, do NOT use ZRS on the ASR protected VM disks.
var asrSafeDiskSkuPrimary = (enableAsrMgmtVm && deploySecondaryRegion && !secCaps.outputs.zoneEnabled) ? 'Premium_LRS' : preferredDiskSkuPrimary

// ===========================================================================
// GLOBAL vWAN RESOURCE (primary region RG, deployed once)
// ===========================================================================
module vwan './connectivity/virtualWan.bicep' = {
  name: 'deploy-vwan'
  scope: resourceGroup(rgPriConnectivity)
  dependsOn: [ rgsPrimary, rgsSecondary ]  // must be deployed before hubs and spokes reference it
  params: {
    location:             primaryRegion
    environment:          env
    customerAbbreviation: custAbbr
    tags:                 commonTags
  }
}

// ===========================================================================
// SPOKE VNETS – deployed before the hub so vwanHub can reference their IDs
// ===========================================================================
module priIdentitySpokeVnet './connectivity/vwanSpokeVnet.bicep' = {
  name: 'deploy-pri-identity-spoke'
  scope: resourceGroup(rgPriIdentity)
  dependsOn: [ vwan ]  // vWAN must be deployed before spokes reference it
  params: {
    location:             primaryRegion
    environment:          env
    customerAbbreviation: custAbbr
    regionAbbreviation:   priAbbr
    vnetName:             vnetPriIdentity
    addressPrefix:        priIdentityPrefix
    siteOctet:            priOctet
    spokeType:            'identity'
    dnsServerIps:         [priDc1Ip, priDc2Ip]
    tags:                 commonTags
  }
}

module priManagementSpokeVnet './connectivity/vwanSpokeVnet.bicep' = {
  name: 'deploy-pri-management-spoke'
  scope: resourceGroup(rgPriManagement)
  dependsOn: [ vwan ]  // vWAN must be deployed before spokes reference it
  params: {
    location:             primaryRegion
    environment:          env
    customerAbbreviation: custAbbr
    regionAbbreviation:   priAbbr
    vnetName:             vnetPriManagement
    addressPrefix:        priManagementPrefix
    siteOctet:            priOctet
    spokeType:            'management'
    dnsServerIps:         [priDc1Ip, priDc2Ip]
    tags:                 commonTags
  }
}

module secIdentitySpokeVnet './connectivity/vwanSpokeVnet.bicep' = if (deploySecondaryRegion) {
  name: 'deploy-sec-identity-spoke'
  scope: resourceGroup(rgSecIdentity)
  dependsOn: [ vwan ]  // vWAN must be deployed before spokes reference it
  params: {
    location:             resolvedSecondaryRegion
    environment:          env
    customerAbbreviation: custAbbr
    regionAbbreviation:   secAbbr
    vnetName:             vnetSecIdentity
    addressPrefix:        secIdentityPrefix
    siteOctet:            secOctet
    spokeType:            'identity'
    dnsServerIps:         [secDc1Ip]
    tags:                 commonTags
  }
}

module secManagementSpokeVnet './connectivity/vwanSpokeVnet.bicep' = if (deploySecondaryRegion) {
  name: 'deploy-sec-management-spoke'
  scope: resourceGroup(rgSecManagement)
  dependsOn: [ vwan ]  // vWAN must be deployed before spokes reference it
  params: {
    location:             resolvedSecondaryRegion
    environment:          env
    customerAbbreviation: custAbbr
    regionAbbreviation:   secAbbr
    vnetName:             vnetSecManagement
    addressPrefix:        secManagementPrefix
    siteOctet:            secOctet
    spokeType:            'management'
    dnsServerIps:         [secDc1Ip]
    tags:                 commonTags
  }
}

// ===========================================================================
// vWAN HUBS + AZURE FIREWALL (after spokes so VNet IDs are known)
// ===========================================================================
module priVwanHub './connectivity/vwanHub.bicep' = {
  name: 'deploy-pri-vwan-hub'
  scope: resourceGroup(rgPriConnectivity)
  params: {
    location:           primaryRegion
    environment:        env
    customerAbbreviation: custAbbr
    regionAbbreviation: priAbbr
    vwanId:             vwan.outputs.vwanId
    hubAddressPrefix:   resolvedPrimaryHubPrefix
    firewallSkuTier:    firewallSkuTier
    deployVpnGateway:         deployVpnGateway
    vpnGwScaleUnit:           vpnGwScaleUnit
    identityType:             identityType
    primarySiteOctet:         priOctet
    secondarySiteOctet:       secOctet
    deploySecondaryRegionRules: deploySecondaryRegion
    identityVnetId:           priIdentitySpokeVnet.outputs.vnetId
    managementVnetId:   priManagementSpokeVnet.outputs.vnetId
    tags:               commonTags
  }
}

module secVwanHub './connectivity/vwanHub.bicep' = if (deploySecondaryRegion) {
  name: 'deploy-sec-vwan-hub'
  scope: resourceGroup(rgSecConnectivity)
  params: {
    location:           resolvedSecondaryRegion
    environment:        env
    customerAbbreviation: custAbbr
    regionAbbreviation: secAbbr
    vwanId:             vwan.outputs.vwanId
    hubAddressPrefix:   resolvedSecondaryHubPrefix
    firewallSkuTier:    firewallSkuTier
    deployVpnGateway:         deployVpnGateway
    vpnGwScaleUnit:           vpnGwScaleUnit
    identityType:             identityType
    primarySiteOctet:         secOctet
    secondarySiteOctet:       priOctet
    deploySecondaryRegionRules: false
    identityVnetId:           deploySecondaryRegion ? secIdentitySpokeVnet.outputs.vnetId : ''
    managementVnetId:   deploySecondaryRegion ? secManagementSpokeVnet.outputs.vnetId : ''
    tags:               commonTags
  }
}

// ===========================================================================
// IDENTITY – IaaS Domain Controllers (shared module)
// nextHopIp = Azure Firewall private IP (routing intent handles the rest)
// hubVnetId not needed in vWAN variant – pass empty string; the shared
// identity module uses hubVnetId only for peering which doesn't apply here.
// ===========================================================================
module priIdentity '../../shared/identity/entrads/entraDomainServices.bicep' = {
  name: 'deploy-pri-identity'
  scope: resourceGroup(rgPriIdentity)
  params: {
    location:             primaryRegion
    environment:          env
    customerAbbreviation: custAbbr
    regionAbbreviation:   priAbbr
    vnetName:             vnetPriIdentity
    addressPrefix:        priIdentityPrefix
    siteOctet:            priOctet
    hubVnetId:            ''               // vWAN: no hub VNet ID for peering
    nextHopIp:            priVwanHub.outputs.firewallPrivateIp
    onPremAddressPrefix:  onPremAddressPrefix
    adminUsername:        adminUsername
    adminPassword:        adminPassword
    dcCount:              0
    entraDsSku:           entraDsSku
    enableSecureLdap:     enableSecureLdap
    dcVmSize:             dcVmSize
    customerDomainName:   customerDomainName
    tags:                 commonTags
  }
}

module priManagement '../../shared/management/managementVnet.bicep' = {
  name: 'deploy-pri-management'
  scope: resourceGroup(rgPriManagement)
  params: {
    location:             primaryRegion
    environment:          env
    customerAbbreviation: custAbbr
    regionAbbreviation:   priAbbr
    vnetName:             vnetPriManagement
    addressPrefix:        priManagementPrefix
    siteOctet:            priOctet
    hubVnetId:            ''
    bastionSubnetId:      priManagementSpokeVnet.outputs.bastionSubnetId
    nextHopIp:            priVwanHub.outputs.firewallPrivateIp
    onPremAddressPrefix:  onPremAddressPrefix
    adminUsername:        adminUsername
    adminPassword:        adminPassword
    mgmtVmSize:           mgmtVmSize
    zoneEnabled: priCaps.outputs.zoneEnabled
    zonesAll: priCaps.outputs.zonesAll
    zonesSingle: priCaps.outputs.zonesSingle
    diskSku: asrSafeDiskSkuPrimary
    tags:                 commonTags
  }
}

module secIdentity '../../shared/identity/entrads/entraDomainServices.bicep' = if (deploySecondaryRegion) {
  name: 'deploy-sec-identity'
  scope: resourceGroup(rgSecIdentity)
  params: {
    location:             resolvedSecondaryRegion
    environment:          env
    customerAbbreviation: custAbbr
    regionAbbreviation:   secAbbr
    vnetName:             vnetSecIdentity
    addressPrefix:        secIdentityPrefix
    siteOctet:            secOctet
    hubVnetId:            ''
    nextHopIp:            deploySecondaryRegion ? secVwanHub.outputs.firewallPrivateIp : ''
    onPremAddressPrefix:  onPremAddressPrefix
    adminUsername:        adminUsername
    adminPassword:        adminPassword
    dcCount:              0
    entraDsSku:           entraDsSku
    enableSecureLdap:     enableSecureLdap
    dcVmSize:             dcVmSize
    customerDomainName:   customerDomainName
    tags:                 commonTags
  }
}

module secManagement '../../shared/management/managementVnet.bicep' = if (deploySecondaryRegion) {
  name: 'deploy-sec-management'
  scope: resourceGroup(rgSecManagement)
  params: {
    location:             resolvedSecondaryRegion
    environment:          env
    customerAbbreviation: custAbbr
    regionAbbreviation:   secAbbr
    vnetName:             vnetSecManagement
    addressPrefix:        secManagementPrefix
    siteOctet:            secOctet
    hubVnetId:            ''
    bastionSubnetId:      deploySecondaryRegion ? secManagementSpokeVnet.outputs.bastionSubnetId : ''
    nextHopIp:            deploySecondaryRegion ? secVwanHub.outputs.firewallPrivateIp : ''
    onPremAddressPrefix:  onPremAddressPrefix
    adminUsername:        adminUsername
    adminPassword:        adminPassword
    mgmtVmSize:           mgmtVmSize
    zoneEnabled: secCaps.outputs.zoneEnabled
    zonesAll: secCaps.outputs.zonesAll
    zonesSingle: secCaps.outputs.zonesSingle
    diskSku: preferredDiskSkuSecondary
    tags:                 commonTags
  }
}

// ===========================================================================
// MONITORING (shared)
// ===========================================================================
module monitoring '../../shared/monitoring/centralMonitoring.bicep' = {
  name: 'deploy-monitoring'
  scope: resourceGroup(rgPriManagement)
  params: {
    location:             primaryRegion
    environment:          env
    customerAbbreviation: custAbbr
    alertEmailAddress:    alertEmailAddress
    retentionDays:        lawRetentionDays
    tags:                 commonTags
    vmInsightsVms: priAllVmInsightsList
  }
}

// ===========================================================================
// GOVERNANCE POLICIES (shared)
// ===========================================================================
module governancePolicies '../../shared/governance/policies.bicep' = {
  name: 'deploy-governance-policies'
  params: {
    environment:          env
    customerAbbreviation: custAbbr
    primaryRegion:        primaryRegion
    secondaryRegion:      resolvedSecondaryRegion
    lawResourceId:        monitoring.outputs.lawId
    dcrResourceId:        monitoring.outputs.dcrId
  }
}

// ===========================================================================
// BACKUP (shared)
// ===========================================================================
// Identity backup: not deployed for Entra DS variants — Microsoft manages all backups
// and HA for the managed domain. Azure Backup is not applicable to the PaaS identity layer.

module backupManagementPrimary '../../shared/backup/backupAndRecovery.bicep' = if (enableVmBackup) {
  name: 'deploy-backup-management-primary'
  scope: resourceGroup(rgPriManagement)
  params: {
    location:             primaryRegion
    environment:          env
    customerAbbreviation: custAbbr
    region:               primaryRegion
    resourceGroupContext: 'management'
    tags:                 commonTags
    vmBackupTargets: [{
      vmId:   priManagement.outputs.mgmtVmId
      vmName: priManagement.outputs.mgmtVmName
      rgName: rgPriManagement
    }]
    diskBackupTargets: []
    zoneEnabled: priCaps.outputs.zoneEnabled
  }
}

module asrCacheStorage '../../shared/backup/asrCacheStorage.bicep' = if (enableAsrMgmtVm && deploySecondaryRegion) {
  name: 'deploy-asr-cache-storage'
  scope: resourceGroup(rgPriConnectivity)
  params: {
    location:             primaryRegion
    environment:          env
    customerAbbreviation: custAbbrLo
    region:               primaryRegion
    tags:                 commonTags
  }
}

module asrMgmtVm '../../shared/backup/asrReplication.bicep' = if (enableAsrMgmtVm && deploySecondaryRegion) {
  name: 'deploy-asr-mgmt-vm'
  scope: resourceGroup(rgSecManagement)
  params: {
    location:               resolvedSecondaryRegion
    environment:            env
    customerAbbreviation:   custAbbr
    region:                 resolvedSecondaryRegion
    primaryRegion:          primaryRegion
    tags:                   commonTags
    sourceVmId:             priManagement.outputs.mgmtVmId
    sourceVmName:           priManagement.outputs.mgmtVmName
    sourceVmOsDiskId:       priManagement.outputs.mgmtVmOsDiskId
    sourceVmLocation:       primaryRegion
    sourceMgmtVnetId:       priManagementSpokeVnet.outputs.vnetId
    targetMgmtVnetId:       deploySecondaryRegion ? secManagementSpokeVnet.outputs.vnetId : ''
    cacheStorageAccountId:  (enableAsrMgmtVm && deploySecondaryRegion) ? asrCacheStorage.outputs.storageAccountId : ''
  }
}

// ===========================================================================
// OUTPUTS
// ===========================================================================
output vwanId                  string = vwan.outputs.vwanId
output primaryFirewallId       string = priVwanHub.outputs.firewallId
output primaryFirewallPrivateIp string = priVwanHub.outputs.firewallPrivateIp
output primaryVhubId           string = priVwanHub.outputs.vhubId
output primaryVpnGatewayId     string = deployVpnGateway ? priVwanHub.outputs.vpnGatewayId : 'not-deployed'
output vpnGatewayDeployed      bool   = deployVpnGateway
output lawId                   string = monitoring.outputs.lawId
output lawWorkspaceId          string = monitoring.outputs.lawWorkspaceId
output actionGroupId           string = monitoring.outputs.actionGroupId
output primaryRsvId            string = enableVmBackup ? backupManagementPrimary.outputs.rsvId : 'not-enabled'

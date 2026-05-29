// =============================================================================
// Espria Azure Base Landing Zone - Main Orchestration
// =============================================================================
// Deployment model : Single Subscription, Multi-Region Hub-Spoke
// NVA              : Sophos XG (primary + secondary regions)
// Identity         : Microsoft Entra Domain Services (managed domain)
// Hub-to-Hub       : Core Connectivity VNets peered across regions
// Aligns with      : CAF, WAF (Reliability, Security, Operational Excellence)
// Identity Type    : Microsoft Entra Domain Services (Managed Domain)
// =============================================================================

targetScope = 'subscription'

// ---------------------------------------------------------------------------
// Customer Identity Parameters
// ---------------------------------------------------------------------------
@description('Customer full name (e.g., Contoso Ltd)')
param customerName string

@description('3–5 character customer abbreviation used in resource names (e.g., CON)')
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
// All Azure public regions are supported. Defaults to UK South / UK West.
// If secondaryRegion is left as 'auto', it is derived from the Microsoft
// region-pair documented map below.
// ---------------------------------------------------------------------------
@description('Primary Azure region for the Landing Zone')
@allowed([
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

@description('Secondary Azure region. Set to "auto" to automatically select the Microsoft-documented paired region for the primary.')
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

@description('Deploy resources into the secondary region. Set to false for primary-only deployments.')
param deploySecondaryRegion bool = true

//---------------------------------------------------------------------------
// Region Zone and Disk Redundancy Parameters
//---------------------------------------------------------------------------

@description('Attempt to use availability zones where supported')
param useAvailabilityZones bool = true

@description('Prefer ZRS managed disks where supported (non-ASR workloads).')
param preferZrsDisks bool = true

// ---------------------------------------------------------------------------
// Environment
// ---------------------------------------------------------------------------
@description('Deployment environment')
@allowed(['prod', 'dev', 'uat'])
param environment string = 'prod'

// ---------------------------------------------------------------------------
// Networking
// ---------------------------------------------------------------------------
@description('Primary region site ID (101–199 for production). Used as 2nd octet of 10.x.0.0/16 per Espria networking standards.')
@minValue(101)
@maxValue(199)
param primaryRegionSiteId int = 101

@description('Secondary region site ID (101–199 for production). Used as 2nd octet of 10.x.0.0/16 per Espria networking standards.')
@minValue(101)
@maxValue(199)
param secondaryRegionSiteId int = 102

@description('On-premises address prefix used in spoke UDRs (e.g., 10.1.0.0/16)')
param onPremAddressPrefix string = '10.1.0.0/16'

// ---------------------------------------------------------------------------
// Sophos XG NVA Parameters
// ---------------------------------------------------------------------------
@description('Sophos XG NVA VM size')
@allowed ([
  'Standard_B2ms'
  'Standard_B4ms'
  'Standard_D2s_v5'
  'Standard_D4s_v5'
  'Standard_D8s_v5'
  'Standard_D2ds_v5'
  'Standard_D4ds_v5'
  'Standard_D8ds_v5'
  'Standard_F2s_v2'
  'Standard_F4s_v2'
  'Standard_F8s_v2'
])
param sophosVmSize string = 'Standard_D2s_v5'

@description('Sophos XG Marketplace image version. Use "latest" or a specific version string.')
param sophosImageVersion string = 'latest'

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
@description('Team or individual who created this deployment')
param createdBy string = 'Espria'

@description('Team responsible for ongoing management (typically Espria managed service)')
param managedBy string = 'Espria'

// ---------------------------------------------------------------------------
// Monitoring Parameters
// ---------------------------------------------------------------------------
@description('Alert notification email address for the Espria managed service NOC')
param alertEmailAddress string = 'alerts@espria.com'

@description('Log Analytics Workspace retention in days')
@minValue(30)
@maxValue(730)
param lawRetentionDays int = 90

// ---------------------------------------------------------------------------
// Backup Parameters
// ---------------------------------------------------------------------------
@description('Enable Azure Backup for DC VMs (Recovery Services Vault, Enhanced Policy)')
param enableVmBackup bool = true

@description('Enable Azure Disk Backup for Sophos XG NVA disks (Backup Vault)')
param enableNvaDiskBackup bool = true

@description('Enable Azure Site Recovery for the Management VM (primary → secondary)')
param enableAsrMgmtVm bool = true

// ---------------------------------------------------------------------------
// Microsoft Azure Region-Pair Map
// Source: https://learn.microsoft.com/azure/reliability/cross-region-replication-azure
// Used to auto-derive secondaryRegion when set to 'auto'.
// Where a region has no standard pair (e.g. Brazil Southeast, West India),
// a sensible geographic neighbour is used as the fallback.
// ---------------------------------------------------------------------------
var regionPairMap = {
  australiacentral:    'australiacentral2'
  australiacentral2:   'australiacentral'
  australiaeast:       'australiasoutheast'
  australiasoutheast:  'australiaeast'
  brazilsouth:         'southcentralus'
  brazilsoutheast:     'brazilsouth'
  canadacentral:       'canadaeast'
  canadaeast:          'canadacentral'
  centralindia:        'southindia'
  centralus:           'eastus2'
  eastasia:            'southeastasia'
  eastus:              'westus'
  eastus2:             'centralus'
  francecentral:       'francesouth'
  francesouth:         'francecentral'
  germanynorth:        'germanywestcentral'
  germanywestcentral:  'germanynorth'
  israelcentral:       'italynorth'
  italynorth:          'israelcentral'
  japaneast:           'japanwest'
  japanwest:           'japaneast'
  jioindiacentral:     'jioindiawest'
  jioindiawest:        'jioindiacentral'
  koreacentral:        'koreasouth'
  koreasouth:          'koreacentral'
  mexicocentral:       'southcentralus'
  newzealandnorth:     'australiaeast'
  northcentralus:      'southcentralus'
  northeurope:         'westeurope'
  norwayeast:          'norwaywest'
  norwaywest:          'norwayeast'
  polandcentral:       'germanywestcentral'
  qatarcentral:        'uaenorth'
  southafricanorth:    'southafricawest'
  southafricawest:     'southafricanorth'
  southcentralus:      'northcentralus'
  southeastasia:       'eastasia'
  southindia:          'centralindia'
  spaincentral:        'francecentral'
  swedencentral:       'swedensouth'
  swedensouth:         'swedencentral'
  switzerlandnorth:    'switzerlandwest'
  switzerlandwest:     'switzerlandnorth'
  uaecentral:          'uaenorth'
  uaenorth:            'uaecentral'
  uksouth:             'ukwest'
  ukwest:              'uksouth'
  westcentralus:       'westus2'
  westeurope:          'northeurope'
  westindia:           'southindia'
  westus:              'eastus'
  westus2:             'westcentralus'
  westus3:             'eastus'
}

// Resolve secondary region: use the pair map when 'auto', otherwise use the explicit value
var resolvedSecondaryRegion = secondaryRegion == 'auto' ? regionPairMap[primaryRegion] : secondaryRegion

// ---------------------------------------------------------------------------
// Region abbreviation map – used in resource names
// ---------------------------------------------------------------------------
var regionAbbrevMap = {
  australiacentral:    'ACL'
  australiacentral2:   'AC2'
  australiaeast:       'AEA'
  australiasoutheast:  'ASE'
  brazilsouth:         'BRS'
  brazilsoutheast:     'BSE'
  canadacentral:       'CAC'
  canadaeast:          'CAE'
  centralindia:        'CIN'
  centralus:           'CUS'
  eastasia:            'EAP'
  eastus:              'EUS'
  eastus2:             'EU2'
  francecentral:       'FRC'
  francesouth:         'FRS'
  germanynorth:        'GNO'
  germanywestcentral:  'GWC'
  israelcentral:       'ILC'
  italynorth:          'ITN'
  japaneast:           'JPE'
  japanwest:           'JPW'
  jioindiacentral:     'JIC'
  jioindiawest:        'JIW'
  koreacentral:        'KRC'
  koreasouth:          'KRS'
  mexicocentral:       'MXC'
  newzealandnorth:     'NZN'
  northcentralus:      'NCU'
  northeurope:         'NEU'
  norwayeast:          'NOE'
  norwaywest:          'NOW'
  polandcentral:       'POC'
  qatarcentral:        'QAC'
  southafricanorth:    'SAN'
  southafricawest:     'SAW'
  southcentralus:      'SCU'
  southeastasia:       'SEA'
  southindia:          'SIN'
  spaincentral:        'SPC'
  swedencentral:       'SWC'
  swedensouth:         'SWS'
  switzerlandnorth:    'CHN'
  switzerlandwest:     'CHW'
  uaecentral:          'UAC'
  uaenorth:            'UAN'
  uksouth:             'UKS'
  ukwest:              'UKW'
  westcentralus:       'WCU'
  westeurope:          'WEU'
  westindia:           'WIN'
  westus:              'WUS'
  westus2:             'WU2'
  westus3:             'WU3'
}

// ---------------------------------------------------------------------------
// Derived naming variables
// ---------------------------------------------------------------------------
var custAbbr   = toUpper(customerAbbreviation)
var custAbbrLo = toLower(customerAbbreviation)
var env        = environment

var priAbbr = regionAbbrevMap[primaryRegion]
var secAbbr = regionAbbrevMap[resolvedSecondaryRegion]

// Human-readable location tags derived from region name
var regionDisplayMap = {
  australiacentral:    'Australia Central'
  australiacentral2:   'Australia Central 2'
  australiaeast:       'Australia East'
  australiasoutheast:  'Australia Southeast'
  brazilsouth:         'Brazil South'
  brazilsoutheast:     'Brazil Southeast'
  canadacentral:       'Canada Central'
  canadaeast:          'Canada East'
  centralindia:        'Central India'
  centralus:           'Central US'
  eastasia:            'East Asia'
  eastus:              'East US'
  eastus2:             'East US 2'
  francecentral:       'France Central'
  francesouth:         'France South'
  germanynorth:        'Germany North'
  germanywestcentral:  'Germany West Central'
  israelcentral:       'Israel Central'
  italynorth:          'Italy North'
  japaneast:           'Japan East'
  japanwest:           'Japan West'
  jioindiacentral:     'Jio India Central'
  jioindiawest:        'Jio India West'
  koreacentral:        'Korea Central'
  koreasouth:          'Korea South'
  mexicocentral:       'Mexico Central'
  newzealandnorth:     'New Zealand North'
  northcentralus:      'North Central US'
  northeurope:         'North Europe'
  norwayeast:          'Norway East'
  norwaywest:          'Norway West'
  polandcentral:       'Poland Central'
  qatarcentral:        'Qatar Central'
  southafricanorth:    'South Africa North'
  southafricawest:     'South Africa West'
  southcentralus:      'South Central US'
  southeastasia:       'Southeast Asia'
  southindia:          'South India'
  spaincentral:        'Spain Central'
  swedencentral:       'Sweden Central'
  swedensouth:         'Sweden South'
  switzerlandnorth:    'Switzerland North'
  switzerlandwest:     'Switzerland West'
  uaecentral:          'UAE Central'
  uaenorth:            'UAE North'
  uksouth:             'UK South'
  ukwest:              'UK West'
  westcentralus:       'West Central US'
  westeurope:          'West Europe'
  westindia:           'West India'
  westus:              'West US'
  westus2:             'West US 2'
  westus3:             'West US 3'
}

var tagLocationPrimary   = regionDisplayMap[primaryRegion]
var tagLocationSecondary = regionDisplayMap[resolvedSecondaryRegion]

// ---------------------------------------------------------------------------
// Address spaces – 10.{siteId}.0.0/16 per site (Espria networking standards)
// ---------------------------------------------------------------------------
var priOctet = primaryRegionSiteId
var secOctet = secondaryRegionSiteId

var priConnectivityPrefix = '10.${priOctet}.0.0/21'
var priIdentityPrefix     = '10.${priOctet}.8.0/22'
var priManagementPrefix   = '10.${priOctet}.248.0/21'

var secConnectivityPrefix = '10.${secOctet}.0.0/21'
var secIdentityPrefix     = '10.${secOctet}.8.0/22'
var secManagementPrefix   = '10.${secOctet}.248.0/21'

// ---------------------------------------------------------------------------
// Resource Group names (rg-{env}-{function}-{CUST}-{region}-01)
// ---------------------------------------------------------------------------
var rgPriConnectivity = 'rg-${env}-core-connectivity-${custAbbr}-${primaryRegion}-01'
var rgPriIdentity     = 'rg-${env}-core-identity-${custAbbr}-${primaryRegion}-01'
var rgPriManagement   = 'rg-${env}-core-management-${custAbbr}-${primaryRegion}-01'

var rgSecConnectivity = 'rg-${env}-core-connectivity-${custAbbr}-${resolvedSecondaryRegion}-01'
var rgSecIdentity     = 'rg-${env}-core-identity-${custAbbr}-${resolvedSecondaryRegion}-01'
var rgSecManagement   = 'rg-${env}-core-management-${custAbbr}-${resolvedSecondaryRegion}-01'

// ---------------------------------------------------------------------------
// VNet names
// ---------------------------------------------------------------------------
var vnetPriConnectivity = 'vnet-${env}-core-connectivity-${custAbbr}-${primaryRegion}-01'
var vnetPriIdentity     = 'vnet-${env}-core-identity-${custAbbr}-${primaryRegion}-01'
var vnetPriManagement   = 'vnet-${env}-core-management-${custAbbr}-${primaryRegion}-01'

var vnetSecConnectivity = 'vnet-${env}-core-connectivity-${custAbbr}-${resolvedSecondaryRegion}-01'
var vnetSecIdentity     = 'vnet-${env}-core-identity-${custAbbr}-${resolvedSecondaryRegion}-01'
var vnetSecManagement   = 'vnet-${env}-core-management-${custAbbr}-${resolvedSecondaryRegion}-01'

// Common tags
var commonTags = {
  CreatedBy:   createdBy
  ManagedBy:   managedBy
  Environment: env
  Customer:    customerName
  DeployedBy:  'Espria-LZ-Bicep'
  Variant:     'sophos-nva-entrads'
}

// Pre-computed VM lists for monitoring (Entra DS has no DC VMs)
var priMgmtVmInsightsList = [{ id: priManagement.outputs.mgmtVmId, location: primaryRegion }]
var priAllVmInsightsList  = priMgmtVmInsightsList

// ===========================================================================
// MANAGEMENT GROUPS
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
// PRIMARY REGION – RESOURCE GROUPS
// ===========================================================================
module rgsPrimary '../../shared/governance/resourceGroups.bicep' = {
  name: 'deploy-rgs-primary'
  params: {
    location:             primaryRegion
    customerAbbreviation: custAbbr
    region:               primaryRegion
    environment:          env
    tags:                 union(commonTags, { Location: tagLocationPrimary })
  }
}

// ===========================================================================
// PRIMARY REGION – CONNECTIVITY
// ===========================================================================
module priConnectivity './connectivity/hubConnectivity.bicep' = {
  name: 'deploy-pri-connectivity'
  scope: resourceGroup(rgPriConnectivity)
  dependsOn: [ rgsPrimary ]
  params: {
    location:             primaryRegion
    environment:          env
    customerAbbreviation: custAbbr
    regionAbbreviation:   priAbbr
    vnetName:             vnetPriConnectivity
    addressPrefix:        priConnectivityPrefix
    siteOctet:            priOctet
    sophosVmSize:         sophosVmSize
    sophosImageVersion:   sophosImageVersion
    adminUsername:        adminUsername
    adminPassword:        adminPassword
    onPremAddressPrefix:  onPremAddressPrefix
    tags:                 union(commonTags, { Location: tagLocationPrimary })
  }
}

// ===========================================================================
// PRIMARY REGION – IDENTITY
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
    hubVnetId:            priConnectivity.outputs.hubVnetId
    nextHopIp:         priConnectivity.outputs.nvaLanPrivateIp
    onPremAddressPrefix:  onPremAddressPrefix
    adminUsername:        adminUsername
    adminPassword:        adminPassword
    dcCount:              0
    entraDsSku:           entraDsSku
    enableSecureLdap:     enableSecureLdap
    dcVmSize:             dcVmSize
    customerDomainName:   customerDomainName
    tags:                 union(commonTags, { Location: tagLocationPrimary })
  }
}

// ===========================================================================
// PRIMARY REGION – MANAGEMENT
// ===========================================================================
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
    hubVnetId:            priConnectivity.outputs.hubVnetId
    bastionSubnetId:      priConnectivity.outputs.bastionSubnetId
    nextHopIp:         priConnectivity.outputs.nvaLanPrivateIp
    onPremAddressPrefix:  onPremAddressPrefix
    adminUsername:        adminUsername
    adminPassword:        adminPassword
    mgmtVmSize:           mgmtVmSize
    zoneEnabled: priCaps.outputs.zoneEnabled
    zonesAll: priCaps.outputs.zonesAll
    zonesSingle: priCaps.outputs.zonesSingle
    diskSku: asrSafeDiskSkuPrimary
    tags:                 union(commonTags, { Location: tagLocationPrimary })
    
  }
}

// ===========================================================================
// SECONDARY REGION
// ===========================================================================
module rgsSecondary '../../shared/governance/resourceGroups.bicep' = if (deploySecondaryRegion) {
  name: 'deploy-rgs-secondary'
  params: {
    location:             resolvedSecondaryRegion
    customerAbbreviation: custAbbr
    region:               resolvedSecondaryRegion
    environment:          env
    tags:                 union(commonTags, { Location: tagLocationSecondary })
  }
}

module secConnectivity './connectivity/hubConnectivity.bicep' = if (deploySecondaryRegion) {
  name: 'deploy-sec-connectivity'
  scope: resourceGroup(rgSecConnectivity)
  dependsOn: [ rgsSecondary ]
  params: {
    location:             resolvedSecondaryRegion
    environment:          env
    customerAbbreviation: custAbbr
    regionAbbreviation:   secAbbr
    vnetName:             vnetSecConnectivity
    addressPrefix:        secConnectivityPrefix
    siteOctet:            secOctet
    sophosVmSize:         sophosVmSize
    sophosImageVersion:   sophosImageVersion
    adminUsername:        adminUsername
    adminPassword:        adminPassword
    onPremAddressPrefix:  onPremAddressPrefix
    tags:                 union(commonTags, { Location: tagLocationSecondary })
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
    hubVnetId:            deploySecondaryRegion ? secConnectivity.outputs.hubVnetId : ''
    nextHopIp:         deploySecondaryRegion ? secConnectivity.outputs.nvaLanPrivateIp : ''
    onPremAddressPrefix:  onPremAddressPrefix
    adminUsername:        adminUsername
    adminPassword:        adminPassword
    dcCount:              0
    entraDsSku:           entraDsSku
    enableSecureLdap:     enableSecureLdap
    dcVmSize:             dcVmSize
    customerDomainName:   customerDomainName
    tags:                 union(commonTags, { Location: tagLocationSecondary })
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
    hubVnetId:            deploySecondaryRegion ? secConnectivity.outputs.hubVnetId : ''
    bastionSubnetId:      deploySecondaryRegion ? secConnectivity.outputs.bastionSubnetId : ''
    nextHopIp:         deploySecondaryRegion ? secConnectivity.outputs.nvaLanPrivateIp : ''
    onPremAddressPrefix:  onPremAddressPrefix
    adminUsername:        adminUsername
    adminPassword:        adminPassword
    mgmtVmSize:           mgmtVmSize
    tags:                 union(commonTags, { Location: tagLocationSecondary })
    zoneEnabled: secCaps.outputs.zoneEnabled
    zonesAll: secCaps.outputs.zonesAll
    zonesSingle: secCaps.outputs.zonesSingle
    diskSku: preferredDiskSkuSecondary
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
// HUB → SPOKE RETURN PEERINGS
// ===========================================================================
module priHubToIdentity './connectivity/spokeToHubPeering.bicep' = {
  name: 'deploy-pri-hub-to-identity'
  scope: resourceGroup(rgPriConnectivity)
  params: {
    hubVnetName:           vnetPriConnectivity
    spokeVnetId:           priIdentity.outputs.identityVnetId
    spokeLabel:            'identity'
    allowForwardedTraffic: true
  }
}

module priHubToManagement './connectivity/spokeToHubPeering.bicep' = {
  name: 'deploy-pri-hub-to-management'
  scope: resourceGroup(rgPriConnectivity)
  params: {
    hubVnetName:           vnetPriConnectivity
    spokeVnetId:           priManagement.outputs.mgmtVnetId
    spokeLabel:            'management'
    allowForwardedTraffic: true
  }
}

module secHubToIdentity './connectivity/spokeToHubPeering.bicep' = if (deploySecondaryRegion) {
  name: 'deploy-sec-hub-to-identity'
  scope: resourceGroup(rgSecConnectivity)
  params: {
    hubVnetName:           vnetSecConnectivity
    spokeVnetId:           deploySecondaryRegion ? secIdentity.outputs.identityVnetId : ''
    spokeLabel:            'identity'
    allowForwardedTraffic: true
  }
}

module secHubToManagement './connectivity/spokeToHubPeering.bicep' = if (deploySecondaryRegion) {
  name: 'deploy-sec-hub-to-management'
  scope: resourceGroup(rgSecConnectivity)
  params: {
    hubVnetName:           vnetSecConnectivity
    spokeVnetId:           deploySecondaryRegion ? secManagement.outputs.mgmtVnetId : ''
    spokeLabel:            'management'
    allowForwardedTraffic: true
  }
}

// ===========================================================================
// HUB-TO-HUB PEERING (primary ↔ secondary connectivity VNets)
// ===========================================================================
module hubTohubPeering './connectivity/hubToHubPeering.bicep' = if (deploySecondaryRegion) {
  name: 'deploy-hub-to-hub-peering'
  params: {
    primaryRg:           rgPriConnectivity
    secondaryRg:         rgSecConnectivity
    primaryVnetName:     vnetPriConnectivity
    secondaryVnetName:   vnetSecConnectivity
    primaryVnetId:       priConnectivity.outputs.hubVnetId
    secondaryVnetId:     deploySecondaryRegion ? secConnectivity.outputs.hubVnetId : ''
  }
}

// ===========================================================================
// OUTPUTS
// ===========================================================================
output primaryRegionResolved      string = primaryRegion
output secondaryRegionResolved    string = resolvedSecondaryRegion
output primaryHubVnetId           string = priConnectivity.outputs.hubVnetId
output primaryNvaLanIp            string = priConnectivity.outputs.nvaLanPrivateIp
output primaryNvaWanIp            string = priConnectivity.outputs.nvaWanPublicIp
output primaryBastionId           string = priManagement.outputs.bastionId
output primaryDcVmIds             array  = priIdentity.outputs.dcVmIds
output secondaryHubVnetId         string = deploySecondaryRegion ? secConnectivity.outputs.hubVnetId      : 'not-deployed'
output secondaryNvaLanIp          string = deploySecondaryRegion ? secConnectivity.outputs.nvaLanPrivateIp : 'not-deployed'
output secondaryBastionId         string = deploySecondaryRegion ? secManagement.outputs.bastionId         : 'not-deployed'
output secondaryDcVmIds           array  = deploySecondaryRegion ? secIdentity.outputs.dcVmIds : []

// ===========================================================================
// MONITORING – Central Log Analytics Workspace + VM Insights
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
    tags:                 union(commonTags, { Location: tagLocationPrimary })
    vmInsightsVms: priAllVmInsightsList
  }
}

// ===========================================================================
// GOVERNANCE – Azure Policy (Allowed Locations, Allowed SKUs, DINE Monitoring)
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
// BACKUP – Identity RG: RSV for DC VMs (primary)
// ===========================================================================
// Identity backup: not deployed for Entra DS variants — Microsoft manages all backups
// and HA for the managed domain. Azure Backup is not applicable to the PaaS identity layer.

// ===========================================================================
// BACKUP – Management RG: RSV for MGMT VM (primary)
// ===========================================================================
module backupManagementPrimary '../../shared/backup/backupAndRecovery.bicep' = if (enableVmBackup) {
  name: 'deploy-backup-management-primary'
  scope: resourceGroup(rgPriManagement)
  params: {
    location:             primaryRegion
    environment:          env
    customerAbbreviation: custAbbr
    region:               primaryRegion
    resourceGroupContext: 'management'
    tags:                 union(commonTags, { Location: tagLocationPrimary })
    vmBackupTargets: [{
      vmId:   priManagement.outputs.mgmtVmId
      vmName: priManagement.outputs.mgmtVmName
      rgName: rgPriManagement
    }]
    diskBackupTargets: []
    zoneEnabled: priCaps.outputs.zoneEnabled
  }
}

// ===========================================================================
// BACKUP – Connectivity RG: Backup Vault for NVA disk (primary)
// ===========================================================================
module backupNvaPrimary '../../shared/backup/backupAndRecovery.bicep' = if (enableNvaDiskBackup) {
  name: 'deploy-backup-nva-primary'
  scope: resourceGroup(rgPriConnectivity)
  params: {
    location:             primaryRegion
    environment:          env
    customerAbbreviation: custAbbr
    region:               primaryRegion
    resourceGroupContext: 'connectivity'
    tags:                 union(commonTags, { Location: tagLocationPrimary })
    vmBackupTargets:   []
    diskBackupTargets: [{ diskId: priConnectivity.outputs.nvaOsDiskId }]
    zoneEnabled: priCaps.outputs.zoneEnabled
  }
}

// ===========================================================================
// BACKUP – Secondary region (conditional)
// ===========================================================================
// Identity backup secondary: not deployed for Entra DS variants.

module backupNvaSecondary '../../shared/backup/backupAndRecovery.bicep' = if (enableNvaDiskBackup && deploySecondaryRegion) {
  name: 'deploy-backup-nva-secondary'
  scope: resourceGroup(rgSecConnectivity)
  params: {
    location:             resolvedSecondaryRegion
    environment:          env
    customerAbbreviation: custAbbr
    region:               resolvedSecondaryRegion
    resourceGroupContext: 'connectivity'
    tags:                 union(commonTags, { Location: tagLocationSecondary })
    vmBackupTargets:   []
    diskBackupTargets: deploySecondaryRegion ? [{ diskId: secConnectivity.outputs.nvaOsDiskId }] : []
    zoneEnabled: secCaps.outputs.zoneEnabled
  }
}

// ===========================================================================
// ASR CACHE STORAGE – Primary connectivity RG (A2A staging)
// ===========================================================================
module asrCacheStorage '../../shared/backup/asrCacheStorage.bicep' = if (enableAsrMgmtVm && deploySecondaryRegion) {
  name: 'deploy-asr-cache-storage'
  scope: resourceGroup(rgPriConnectivity)
  params: {
    location:             primaryRegion
    environment:          env
    customerAbbreviation: custAbbrLo
    region:               primaryRegion
    tags:                 union(commonTags, { Location: tagLocationPrimary })
  }
}

// ===========================================================================
// ASR REPLICATION – Management VM primary → secondary
// ===========================================================================
module asrMgmtVm '../../shared/backup/asrReplication.bicep' = if (enableAsrMgmtVm && deploySecondaryRegion) {
  name: 'deploy-asr-mgmt-vm'
  scope: resourceGroup(rgSecManagement)
  params: {
    location:               resolvedSecondaryRegion
    environment:            env
    customerAbbreviation:   custAbbr
    region:                 resolvedSecondaryRegion
    primaryRegion:          primaryRegion
    tags:                   union(commonTags, { Location: tagLocationSecondary })
    sourceVmId:             priManagement.outputs.mgmtVmId
    sourceVmName:           priManagement.outputs.mgmtVmName
    sourceVmOsDiskId:       priManagement.outputs.mgmtVmOsDiskId
    sourceVmLocation:       primaryRegion
    sourceMgmtVnetId:       priManagement.outputs.mgmtVnetId
    targetMgmtVnetId:       deploySecondaryRegion ? secManagement.outputs.mgmtVnetId : ''
    cacheStorageAccountId:  (enableAsrMgmtVm && deploySecondaryRegion) ? asrCacheStorage.outputs.storageAccountId : ''
  }
}

// Additional outputs for new modules
output lawId              string = monitoring.outputs.lawId
output lawWorkspaceId     string = monitoring.outputs.lawWorkspaceId
output actionGroupId      string = monitoring.outputs.actionGroupId
output primaryRsvId       string = enableVmBackup ? backupManagementPrimary.outputs.rsvId : 'not-enabled'
output primaryBuvId       string = enableNvaDiskBackup ? backupNvaPrimary.outputs.buvId : 'not-enabled'
output asrVaultId         string = (enableAsrMgmtVm && deploySecondaryRegion) ? asrMgmtVm.outputs.rsvAsrId : 'not-enabled'

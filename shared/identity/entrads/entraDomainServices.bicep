// =============================================================================
// shared/identity/entrads/entraDomainServices.bicep
// Microsoft Entra Domain Services – Identity Module
//
// Same VNet/subnet address space as identityVnet.bicep (ADDS variant).
// DomainControllers subnet renamed to EntraDomainServices with mandatory NSG.
// Output contract matches identityVnet.bicep exactly.
//
// Domain name: Must be routable (e.g. aadds.contoso.com). .local not supported.
// Provisioning time: 30–60 minutes after deployment.
// =============================================================================

param location string
param environment string
param customerAbbreviation string
@description('Not used – retained for output contract compatibility')
param regionAbbreviation string
param vnetName string
param addressPrefix string
param siteOctet int
@description('Hub VNet ID for peering. Empty string for vWAN variant.')
param hubVnetId string
@description('Next-hop IP for UDRs. Empty string for vWAN variant.')
param nextHopIp string
param onPremAddressPrefix string = '10.1.0.0/16'
@description('Not used – retained for contract compatibility')
param adminUsername string = ''
@secure()
@description('Not used – retained for contract compatibility')
param adminPassword string = ''
@description('Not used – retained for contract compatibility')
param dcCount int = 0
@description('Not used – retained for contract compatibility')
param dcVmSize string = ''
@description('Managed domain name. Must be routable (e.g. aadds.contoso.com).')
param customerDomainName string
@allowed(['Enterprise','Standard','Premium'])
@description('Enterprise required for replica sets (secondary region).')
param entraDsSku string = 'Enterprise'
@description('Enable Secure LDAP. Certificate must be configured post-deployment.')
param enableSecureLdap bool = false
param tags object

var custAbbr      = toUpper(customerAbbreviation)
var env           = environment
var isVwan        = empty(hubVnetId)
var subnetEntraDs = '10.${siteOctet}.8.0/24'
var subnetPrivEp  = '10.${siteOctet}.11.0/24'
var rtName        = 'rt-${env}-core-identity-${custAbbr}-${location}-01'

// Mandatory NSG for EntraDomainServices subnet
resource nsgEntraDs 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: 'nsg-EntraDomainServices-${vnetName}'
  location: location
  tags: union(tags, { Function: 'Identity', Purpose: 'EntraDS-NSG' })
  properties: {
    securityRules: [
      { name: 'AllowSyncWithAzureAD', properties: { priority: 101, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: 'AzureActiveDirectoryDomainServices', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '443', description: 'Required: management plane sync' } }
      { name: 'AllowPSRemoting',      properties: { priority: 301, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: 'AzureActiveDirectoryDomainServices', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '5986', description: 'Required: WinRM management plane' } }
      { name: 'AllowRD',              properties: { priority: 201, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: 'CorpNetSaw', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '3389', description: 'Required: RDP diagnostics' } }
      { name: 'AllowVnetInbound',     properties: { priority: 401, direction: 'Inbound', access: 'Allow', protocol: '*', sourceAddressPrefix: 'VirtualNetwork', sourcePortRange: '*', destinationAddressPrefix: 'VirtualNetwork', destinationPortRange: '*', description: 'Allow intra-VNet' } }
      { name: 'DenyAllInbound',       properties: { priority: 4096, direction: 'Inbound', access: 'Deny', protocol: '*', sourceAddressPrefix: '*', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '*', description: 'Deny all other inbound' } }
      { name: 'AllowAllOutbound',     properties: { priority: 100, direction: 'Outbound', access: 'Allow', protocol: '*', sourceAddressPrefix: '*', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '*', description: 'Required: managed domain health reporting' } }
    ]
  }
}

resource nsgPrivEp 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: 'nsg-PrivateEndpoint-${vnetName}'
  location: location
  tags: tags
  properties: { securityRules: [] }
}

// Route table – hub-spoke only; vWAN uses routing intent
resource routeTable 'Microsoft.Network/routeTables@2023-06-01' = if (!isVwan) {
  name: rtName
  location: location
  tags: union(tags, { Function: 'Identity', Purpose: 'UDR-Identity' })
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      { name: 'default-to-fw',   properties: { addressPrefix: '0.0.0.0/0',        nextHopType: 'VirtualAppliance', nextHopIpAddress: nextHopIp } }
      { name: 'on-prem-to-fw',   properties: { addressPrefix: onPremAddressPrefix, nextHopType: 'VirtualAppliance', nextHopIpAddress: nextHopIp } }
    ]
  }
}

resource identityVnet 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: vnetName
  location: location
  tags: union(tags, { Function: 'Identity', Purpose: 'Entra-DS-Spoke', IdentityType: 'EntraDS' })
  properties: {
    addressSpace: { addressPrefixes: [addressPrefix] }
    // DNS IPs configured post-provisioning via PD-01 step
    subnets: [
      {
        name: 'EntraDomainServices'
        properties: {
          addressPrefix:                  subnetEntraDs
          networkSecurityGroup:           { id: nsgEntraDs.id }
          routeTable:                     (!isVwan) ? { id: routeTable.id } : null
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'PrivateEndpoint'
        properties: {
          addressPrefix:                  subnetPrivEp
          networkSecurityGroup:           { id: nsgPrivEp.id }
          routeTable:                     (!isVwan) ? { id: routeTable.id } : null
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-06-01' = if (!isVwan && !empty(hubVnetId)) {
  parent: identityVnet
  name: 'peer-to-hub'
  properties: { remoteVirtualNetwork: { id: hubVnetId }, allowVirtualNetworkAccess: true, allowForwardedTraffic: true, allowGatewayTransit: false, useRemoteGateways: false }
}

// Entra Domain Services managed domain
resource entraDomain 'Microsoft.AAD/domainServices@2022-12-01' = {
  name: customerDomainName
  location: location
  tags: union(tags, { Function: 'Identity', Purpose: 'Entra-DS-Managed-Domain' })
  properties: {
    domainName: customerDomainName
    sku:        entraDsSku
    filteredSync:            'Disabled'
    domainConfigurationType: 'FullySynced'
    replicaSets: [
      {
        location: location
        subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'EntraDomainServices')
      }
    ]
    domainSecuritySettings: {
      ntlmV1:               'Disabled'
      tlsV1:                'Disabled'
      syncNtlmPasswords:    'Enabled'
      syncOnPremPasswords:  'Enabled'
      kerberosRc4Encryption: 'Disabled'
      kerberosArmoring:      'Enabled'
    }
    ldapsSettings: {
      ldaps:          enableSecureLdap ? 'Enabled' : 'Disabled'
      externalAccess: 'Disabled'
    }
    notificationSettings: {
      notifyGlobalAdmins: 'Enabled'
      notifyDcAdmins:     'Enabled'
      additionalRecipients: []
    }
  }
  dependsOn: [identityVnet, nsgEntraDs]
}

// Outputs – identical contract to identityVnet.bicep
output identityVnetId  string = identityVnet.id
output dcVmIds         array  = []
output dcVmNames       array  = []
output dc1StaticIp     string = 'pending-provisioning'
output dc2StaticIp     string = 'pending-provisioning'
output routeTableId    string = (!isVwan) ? routeTable.id : ''
output entraDomainId   string = entraDomain.id
output entraDomainName string = entraDomain.name

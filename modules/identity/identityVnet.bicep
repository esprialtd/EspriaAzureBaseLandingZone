// =============================================================================
// modules/identity/identityVnet.bicep
// Identity spoke VNet with IaaS Domain Controllers
// DC count: 2 in primary region, 1 in secondary (controlled by dcCount param)
// Static IPs assigned per Espria networking standards (10.x.10.11+)
// =============================================================================

param location string
param environment string
param customerAbbreviation string
param regionAbbreviation string
param vnetName string
param addressPrefix string

@description('2nd octet of the 10.x.0.0/16 address space for this region')
param siteOctet int

param hubVnetId string
param nvaPrivateIp string
param onPremAddressPrefix string
param adminUsername string
@secure()
param adminPassword string

@description('Number of DC VMs to deploy (2 for primary, 1 for secondary)')
@minValue(1)
@maxValue(3)
param dcCount int = 2

param dcVmSize string = 'Standard_D2s_v5'
param customerDomainName string
param tags object

var custAbbr = toUpper(customerAbbreviation)
var regAbbr  = toUpper(regionAbbreviation)
var env      = environment

// Subnets
var subnetDcPrefix   = '10.${siteOctet}.8.0/24'
var subnetPrivEp     = '10.${siteOctet}.11.0/24'

// Static DC IPs: 10.x.10.11, 10.x.10.12 (per Espria DC/DNS IP standard)
// Note: Identity VNet uses .8.x range but we follow the DC IP standard within that block
var dcBaseIp   = '10.${siteOctet}.8.'
var dc1Ip      = '${dcBaseIp}11'
var dc2Ip      = '${dcBaseIp}12'

// Resource names
var rtName       = 'rt-${env}-core-identity-${custAbbr}-${location}-01'
var nsgDcName    = 'nsg-DomainControllers-${vnetName}'
var nsgPrivEpName = 'nsg-PrivateEndpoint-${vnetName}'

// ---------------------------------------------------------------------------
// NSGs
// ---------------------------------------------------------------------------
resource nsgDc 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: nsgDcName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-DNS-Inbound'
        properties: {
          priority:                100
          direction:               'Inbound'
          access:                  'Allow'
          protocol:                '*'
          sourceAddressPrefix:     'VirtualNetwork'
          sourcePortRange:         '*'
          destinationAddressPrefix: '*'
          destinationPortRange:    '53'
        }
      }
      {
        name: 'Allow-LDAP-Inbound'
        properties: {
          priority:                110
          direction:               'Inbound'
          access:                  'Allow'
          protocol:                'Tcp'
          sourceAddressPrefix:     'VirtualNetwork'
          sourcePortRange:         '*'
          destinationAddressPrefix: '*'
          destinationPortRange:    '389'
        }
      }
      {
        name: 'Allow-Kerberos-Inbound'
        properties: {
          priority:                120
          direction:               'Inbound'
          access:                  'Allow'
          protocol:                '*'
          sourceAddressPrefix:     'VirtualNetwork'
          sourcePortRange:         '*'
          destinationAddressPrefix: '*'
          destinationPortRange:    '88'
        }
      }
      {
        name: 'Allow-RPC-Inbound'
        properties: {
          priority:                130
          direction:               'Inbound'
          access:                  'Allow'
          protocol:                'Tcp'
          sourceAddressPrefix:     'VirtualNetwork'
          sourcePortRange:         '*'
          destinationAddressPrefix: '*'
          destinationPortRange:    '49152-65535'
        }
      }
      {
        name: 'Deny-All-Internet-Inbound'
        properties: {
          priority:                4000
          direction:               'Inbound'
          access:                  'Deny'
          protocol:                '*'
          sourceAddressPrefix:     'Internet'
          sourcePortRange:         '*'
          destinationAddressPrefix: '*'
          destinationPortRange:    '*'
        }
      }
    ]
  }
}

resource nsgPrivEp 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: nsgPrivEpName
  location: location
  tags: tags
  properties: {}
}

// ---------------------------------------------------------------------------
// Route Table – force traffic through NVA (Sophos XG)
// ---------------------------------------------------------------------------
resource routeTable 'Microsoft.Network/routeTables@2023-06-01' = {
  name: rtName
  location: location
  tags: union(tags, { Function: 'UDR-Identity' })
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'To-Internet'
        properties: {
          addressPrefix:     '0.0.0.0/0'
          nextHopType:       'VirtualAppliance'
          nextHopIpAddress:  nvaPrivateIp
        }
      }
      {
        name: 'To-OnPrem'
        properties: {
          addressPrefix:     onPremAddressPrefix
          nextHopType:       'VirtualAppliance'
          nextHopIpAddress:  nvaPrivateIp
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Identity Spoke VNet
// ---------------------------------------------------------------------------
resource identityVnet 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: vnetName
  location: location
  tags: union(tags, { Function: 'Identity-Spoke' })
  properties: {
    addressSpace: {
      addressPrefixes: [ addressPrefix ]
    }
    dhcpOptions: {
      dnsServers: [ dc1Ip, dc2Ip ]
    }
    subnets: [
      {
        name: 'DomainControllers'
        properties: {
          addressPrefix:               subnetDcPrefix
          networkSecurityGroup:        { id: nsgDc.id }
          routeTable:                  { id: routeTable.id }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'PrivateEndpoint'
        properties: {
          addressPrefix:               subnetPrivEp
          networkSecurityGroup:        { id: nsgPrivEp.id }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Hub peering: Identity spoke → Hub (spoke uses hub for egress)
// ---------------------------------------------------------------------------
resource peerToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-06-01' = {
  name: '${vnetName}/link-to-${last(split(hubVnetId, '/'))}'
  properties: {
    remoteVirtualNetwork:      { id: hubVnetId }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic:     true
    useRemoteGateways:         false
    allowGatewayTransit:       false
  }
  dependsOn: [identityVnet]
}

// ---------------------------------------------------------------------------
// Domain Controller NICs (static IPs)
// ---------------------------------------------------------------------------
var dcStaticIps = [ dc1Ip, dc2Ip, '${dcBaseIp}13' ]

resource dcNics 'Microsoft.Network/networkInterfaces@2023-06-01' = [for i in range(0, dcCount): {
  name: '${custAbbr}-AZ${regAbbr}-DC0${i + 1}-nic'
  location: location
  tags: tags
  properties: {
    enableIPForwarding: false
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet:                    { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'DomainControllers') }
          privateIPAddress:          dcStaticIps[i]
          privateIPAllocationMethod: 'Static'
          primary:                   true
        }
      }
    ]
  }
  dependsOn: [identityVnet]
}]

// ---------------------------------------------------------------------------
// Domain Controller VMs
// Zones: DC1→zone1, DC2→zone2 in primary; DC1→zone1 in secondary
// ---------------------------------------------------------------------------
var dcZones = [['1'], ['2'], ['3']]

resource dcVms 'Microsoft.Compute/virtualMachines@2023-09-01' = [for i in range(0, dcCount): {
  name: '${custAbbr}-AZ${regAbbr}-DC0${i + 1}'
  location: location
  zones: dcZones[i]
  tags: union(tags, { Application: 'Domain Controller', Function: 'Identity Services', Role: 'DC' })
  properties: {
    hardwareProfile: { vmSize: dcVmSize }
    osProfile: {
      computerName:  '${custAbbr}-AZ${regAbbr}-DC0${i + 1}'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode:        'AutomaticByOS'
          assessmentMode:   'ImageDefault'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer:     'WindowsServer'
        sku:       '2025-datacenter-g2'
        version:   'latest'
      }
      osDisk: {
        createOption:       'FromImage'
        managedDisk:        { storageAccountType: 'Premium_LRS' }
        diskSizeGB:         128
        deleteOption:       'Delete'
      }
      dataDisks: [
        {
          lun:          0
          createOption: 'Empty'
          diskSizeGB:   32
          managedDisk:  { storageAccountType: 'Premium_LRS' }
          deleteOption: 'Delete'
          // NTDS/SYSVOL should be placed on data disk, not OS disk
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: dcNics[i].id
          properties: { primary: true, deleteOption: 'Delete' }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: { enabled: true }
    }
  }
}]

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output identityVnetId  string = identityVnet.id
output dcVmIds         array  = [for i in range(0, dcCount): dcVms[i].id]
output dcVmNames       array  = [for i in range(0, dcCount): dcVms[i].name]
output dc1StaticIp     string = dc1Ip
output dc2StaticIp     string = (dcCount > 1) ? dc2Ip : ''
output routeTableId    string = routeTable.id

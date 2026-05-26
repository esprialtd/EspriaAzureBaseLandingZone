// =============================================================================
// modules/connectivity/hubConnectivity.bicep
// Hub VNet for a single region.
// Contains: Sophos XG NVA (LAN + WAN NICs, static IPs required for UDR next-hop),
//           NSGs per subnet, GatewaySubnet/RouteServerSubnet reserved for future use.
// NOTE: VPN connectivity is handled by the Sophos XG NVA – no Azure VPN Gateway
//       is deployed in this Landing Zone.
// NOTE: Azure Bastion is deployed in the Management RG (managementVnet.bicep)
//       but attaches to AzureBastionSubnet in this VNet via cross-RG subnet reference.
// =============================================================================

param location string
param environment string
param customerAbbreviation string
param regionAbbreviation string
param vnetName string
param addressPrefix string

@description('2nd octet of the 10.x.0.0/16 address space for this region')
param siteOctet int

param sophosVmSize string = 'Standard_D2s_v5'
param sophosImageVersion string = 'latest'
param adminUsername string
@secure()
param adminPassword string
param onPremAddressPrefix string = '10.1.0.0/16'
param tags object

var custAbbr = toUpper(customerAbbreviation)
var regAbbr  = toUpper(regionAbbreviation)
var env      = environment

// Subnet prefixes derived from site octet (10.{siteOctet}.x.y)
var subnetNvaLan       = '10.${siteOctet}.0.0/27'    // NVALAN
var subnetNvaWan       = '10.${siteOctet}.0.64/27'   // NVAWAN
var subnetGateway      = '10.${siteOctet}.0.128/27'  // GatewaySubnet  – reserved, no GW deployed
var subnetRouteServer  = '10.${siteOctet}.0.160/27'  // RouteServerSubnet – reserved
var subnetBastion      = '10.${siteOctet}.1.0/26'    // AzureBastionSubnet – used by Bastion in mgmt RG
var subnetPrivEp       = '10.${siteOctet}.7.0/24'    // PrivateEndpoint

// NVA static IPs – MUST remain static: these are the UDR next-hop addresses
// referenced by route tables in every spoke VNet.
var nvaLanIp  = '10.${siteOctet}.0.4'
var nvaWanIp  = '10.${siteOctet}.0.68'

// Resource names
// Sophos XG Marketplace does not support hyphens in VM name – use compact format
// Pattern: {CUST}AZ{REG}SFOS01  e.g. CONAZUKSSFOS01
var nvaName       = '${custAbbr}AZ${regAbbr}SFOS01'
var nvaLanNicName = '${nvaName}-nic-lan'
var nvaWanNicName = '${nvaName}-nic-wan'

// ---------------------------------------------------------------------------
// NSGs
// ---------------------------------------------------------------------------
resource nsgNvaLan 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: 'nsg-NVALAN-${vnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-All-Inbound-LAN'
        properties: {
          priority:                100
          direction:               'Inbound'
          access:                  'Allow'
          protocol:                '*'
          sourceAddressPrefix:     'VirtualNetwork'
          sourcePortRange:         '*'
          destinationAddressPrefix: '*'
          destinationPortRange:    '*'
        }
      }
    ]
  }
}

resource nsgNvaWan 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: 'nsg-NVAWAN-${vnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          priority:                100
          direction:               'Inbound'
          access:                  'Allow'
          protocol:                'Tcp'
          sourceAddressPrefix:     '*'
          sourcePortRange:         '*'
          destinationAddressPrefix: '*'
          destinationPortRange:    '443'
        }
      }
      {
        name: 'Allow-ISAKMP'
        properties: {
          priority:                110
          direction:               'Inbound'
          access:                  'Allow'
          protocol:                'Udp'
          sourceAddressPrefix:     '*'
          sourcePortRange:         '*'
          destinationAddressPrefix: '*'
          destinationPortRange:    '500'
        }
      }
      {
        name: 'Allow-IPSEC-NAT-T'
        properties: {
          priority:                120
          direction:               'Inbound'
          access:                  'Allow'
          protocol:                'Udp'
          sourceAddressPrefix:     '*'
          sourcePortRange:         '*'
          destinationAddressPrefix: '*'
          destinationPortRange:    '4500'
        }
      }
    ]
  }
}

resource nsgPrivEp 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: 'nsg-PrivateEndpoint-${vnetName}'
  location: location
  tags: tags
  properties: {}
}

// ---------------------------------------------------------------------------
// Hub VNet
// ---------------------------------------------------------------------------
resource hubVnet 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: vnetName
  location: location
  tags: union(tags, { Function: 'Hub-Connectivity' })
  properties: {
    addressSpace: {
      addressPrefixes: [ addressPrefix ]
    }
    subnets: [
      {
        name: 'NVALAN'
        properties: {
          addressPrefix:         subnetNvaLan
          networkSecurityGroup:  { id: nsgNvaLan.id }
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'NVAWAN'
        properties: {
          addressPrefix:        subnetNvaWan
          networkSecurityGroup: { id: nsgNvaWan.id }
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: subnetGateway
          // GatewaySubnet cannot have an NSG
        }
      }
      {
        name: 'RouteServerSubnet'
        properties: {
          addressPrefix: subnetRouteServer
          // RouteServerSubnet cannot have an NSG
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: subnetBastion
          // Bastion manages its own NSG separately
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
// Public IPs
// Only the Sophos XG WAN interface has a public IP in this LZ.
// Bastion PIP is created in managementVnet.bicep (Bastion lives in mgmt RG).
// VPN Gateway is not deployed – Sophos XG handles site-to-site VPN.
// ---------------------------------------------------------------------------
resource pipNvaWan 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: 'pip-${nvaName}-wan-01'
  location: location
  tags: union(tags, { Function: 'NVA-WAN' })
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
  zones: ['1', '2', '3']
}

// ---------------------------------------------------------------------------
// Sophos XG NVA – NIC (WAN) with public IP
// ---------------------------------------------------------------------------
resource nvaWanNic 'Microsoft.Network/networkInterfaces@2023-06-01' = {
  name: nvaWanNicName
  location: location
  tags: tags
  properties: {
    enableIPForwarding: true
    ipConfigurations: [
      {
        name: 'wan-ipconfig'
        properties: {
          subnet:                       { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'NVAWAN') }
          privateIPAddress:             nvaWanIp
          privateIPAllocationMethod:    'Static'
          publicIPAddress:              { id: pipNvaWan.id }
          primary:                      true
        }
      }
    ]
  }
  dependsOn: [hubVnet]
}

// ---------------------------------------------------------------------------
// Sophos XG NVA – NIC (LAN) – the next-hop IP used in UDRs
// ---------------------------------------------------------------------------
resource nvaLanNic 'Microsoft.Network/networkInterfaces@2023-06-01' = {
  name: nvaLanNicName
  location: location
  tags: tags
  properties: {
    enableIPForwarding: true
    ipConfigurations: [
      {
        name: 'lan-ipconfig'
        properties: {
          subnet:                    { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'NVALAN') }
          privateIPAddress:          nvaLanIp
          privateIPAllocationMethod: 'Static'
          primary:                   true
        }
      }
    ]
  }
  dependsOn: [hubVnet]
}

// ---------------------------------------------------------------------------
// Sophos XG VM
// NOTE: The Sophos XG image is available via the Azure Marketplace.
// The plan block references the Marketplace offer. Ensure the subscription
// has accepted the Marketplace terms before deploying:
//   az vm image terms accept --publisher sophos --offer sophos-xg --plan byol
// ---------------------------------------------------------------------------
resource sophosNva 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: nvaName
  location: location
  tags: union(tags, { Application: 'Sophos XG Firewall', Function: 'Network Virtual Appliance' })
  plan: {
    name:      'byol'
    publisher: 'sophos'
    product:   'sophos-xg'
  }
  properties: {
    hardwareProfile: { vmSize: sophosVmSize }
    osProfile: {
      computerName:  nvaName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'sophos'
        offer:     'sophos-xg'
        sku:       'byol'
        version:   sophosImageVersion
      }
      osDisk: {
        createOption:       'FromImage'
        managedDisk:        { storageAccountType: 'Premium_LRS' }
        diskSizeGB:         30
        deleteOption:       'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nvaWanNic.id
          properties: { primary: true, deleteOption: 'Delete' }
        }
        {
          id: nvaLanNic.id
          properties: { primary: false, deleteOption: 'Delete' }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: { enabled: true }
    }
  }
}

// ---------------------------------------------------------------------------
// VPN Gateway – NOT deployed in this Landing Zone.
// The Sophos XG NVA provides site-to-site VPN connectivity.
// GatewaySubnet and RouteServerSubnet are provisioned in the VNet above
// so a gateway can be added later without address space changes.
// If a VPN Gateway is required in future, it resides in this same VNet
// (vnet-prod-core-connectivity) – no separate VNet is needed.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Bastion – NOT deployed here. Bastion is deployed in managementVnet.bicep
// into the management RG, but attaches to AzureBastionSubnet in THIS VNet.
// The bastionSubnetId output below is consumed by managementVnet.bicep.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output hubVnetId           string = hubVnet.id
output hubVnetName         string = hubVnet.name
output nvaLanPrivateIp     string = nvaLanIp
output nvaId               string = sophosNva.id
output nvaName             string = sophosNva.name
output nvaOsDiskId         string = sophosNva.properties.storageProfile.osDisk.managedDisk.id
output nvaWanPublicIp      string = pipNvaWan.properties.ipAddress
// Subnet IDs consumed by managementVnet.bicep (for Bastion attachment)
output bastionSubnetId     string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'AzureBastionSubnet')
output nvaLanSubnetId      string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'NVALAN')
// vpnGatewayId intentionally omitted – not deployed in this LZ

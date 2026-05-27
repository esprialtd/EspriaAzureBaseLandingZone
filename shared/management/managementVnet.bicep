// =============================================================================
// modules/management/managementVnet.bicep
// Management spoke VNet – jump/management VM, NSGs, UDRs, hub peering.
// Azure Bastion is deployed HERE (management RG) but attaches to
// AzureBastionSubnet in the connectivity VNet via bastionSubnetId param.
// Management VM NIC uses DHCP – Azure best practice for non-DC workloads.
// =============================================================================

param location string
param environment string
param customerAbbreviation string
param regionAbbreviation string
param vnetName string
param addressPrefix string
param siteOctet int
param hubVnetId string
param zoneEnabled bool
param zonesAll array
param zonesSingle array
param diskSku string

@description('AzureBastionSubnet resource ID from the connectivity VNet. Bastion attaches to the hub VNet subnet to reach all peered spokes. Pass empty string for vWAN variant where Bastion is in the management spoke.')
param bastionSubnetId string

param nextHopIp string
param onPremAddressPrefix string
param adminUsername string
@secure()
param adminPassword string
param mgmtVmSize string = 'Standard_B2ms'
param tags object

var custAbbr = toUpper(customerAbbreviation)
var regAbbr  = toUpper(regionAbbreviation)
var env      = environment

// Subnets (10.{siteOctet}.248.x per Espria standards)
var subnetMgmt   = '10.${siteOctet}.248.0/24'
var subnetPrivEp = '10.${siteOctet}.255.0/24'

var rtName      = 'rt-${env}-core-management-${custAbbr}-${location}-01'
var bastionName = 'bastion-${env}-core-connectivity-${custAbbr}-${location}-01'

// ---------------------------------------------------------------------------
// NSG – Management Servers subnet
// ---------------------------------------------------------------------------
resource nsgMgmt 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: 'nsg-ManagementServers-${vnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP-From-Bastion'
        properties: {
          priority:                100
          direction:               'Inbound'
          access:                  'Allow'
          protocol:                'Tcp'
          sourceAddressPrefix:     'VirtualNetwork'
          sourcePortRange:         '*'
          destinationAddressPrefix: '*'
          destinationPortRange:    '3389'
        }
      }
      {
        name: 'Allow-WinRM-From-VNet'
        properties: {
          priority:                110
          direction:               'Inbound'
          access:                  'Allow'
          protocol:                'Tcp'
          sourceAddressPrefix:     'VirtualNetwork'
          sourcePortRange:         '*'
          destinationAddressPrefix: '*'
          destinationPortRange:    '5986'
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
  name: 'nsg-PrivateEndpoint-${vnetName}'
  location: location
  tags: tags
  properties: {}
}

// ---------------------------------------------------------------------------
// Route Table – force traffic through Sophos XG NVA
// ---------------------------------------------------------------------------
resource routeTable 'Microsoft.Network/routeTables@2023-06-01' = {
  name: rtName
  location: location
  tags: union(tags, { Function: 'UDR-Management' })
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'To-Internet'
        properties: {
          addressPrefix:     '0.0.0.0/0'
          nextHopType:       'VirtualAppliance'
          nextHopIpAddress:  nextHopIp
        }
      }
      {
        name: 'To-OnPrem'
        properties: {
          addressPrefix:     onPremAddressPrefix
          nextHopType:       'VirtualAppliance'
          nextHopIpAddress:  nextHopIp
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Management Spoke VNet
// ---------------------------------------------------------------------------
resource mgmtVnet 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: vnetName
  location: location
  tags: union(tags, { Function: 'Management-Spoke' })
  properties: {
    addressSpace: { addressPrefixes: [ addressPrefix ] }
    subnets: [
      {
        name: 'ManagementServers'
        properties: {
          addressPrefix:        subnetMgmt
          networkSecurityGroup: { id: nsgMgmt.id }
          routeTable:           { id: routeTable.id }
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
// Hub peering: Management spoke → Hub
// ---------------------------------------------------------------------------
resource peerToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-06-01' = if (!empty(hubVnetId)) {
  parent: mgmtVnet
  name:   'link-to-${last(split(hubVnetId, '/'))}'
  properties: {
    remoteVirtualNetwork:      { id: hubVnetId }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic:     true
    useRemoteGateways:         false
    allowGatewayTransit:       false
  }
}

// ---------------------------------------------------------------------------
// Management / Jump VM NIC
// DHCP – Azure best practice for non-DC VMs. The IP is stable for the VM
// lifetime; use Bastion for access (no RDP direct from internet).
// ---------------------------------------------------------------------------
resource mgmtVmNic 'Microsoft.Network/networkInterfaces@2023-06-01' = {
  name: '${custAbbr}-AZ${regAbbr}-MGMT01-nic'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet:                    { id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'ManagementServers') }
          privateIPAllocationMethod: 'Dynamic'   // DHCP – Azure best practice for non-DC VMs
        }
      }
    ]
  }
  dependsOn: [mgmtVnet]
}

// ---------------------------------------------------------------------------
// Management VM
// ---------------------------------------------------------------------------
resource mgmtVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: '${custAbbr}-AZ${regAbbr}-MGMT01'
  location: location
  zones: zoneEnabled ? zonesSingle : null
  tags: union(tags, { Application: 'Management Server', Function: 'Management Services', Role: 'Jump' })
  properties: {
    hardwareProfile: { vmSize: mgmtVmSize }
    osProfile: {
      computerName:  '${custAbbr}-AZ${regAbbr}-MGMT01'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode:      'AutomaticByOS'
          assessmentMode: 'ImageDefault'
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
        createOption: 'FromImage'
        managedDisk:  { storageAccountType: diskSku }
        diskSizeGB:   128
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: mgmtVmNic.id
          properties: { primary: true, deleteOption: 'Delete' }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: { enabled: true }
    }
  }
}

// ---------------------------------------------------------------------------
// Azure Bastion – deployed in the management RG, attaches to the
// AzureBastionSubnet in the connectivity VNet (bastionSubnetId param).
// This is required because Bastion connectivity to peered spoke VMs relies
// on the hub VNet peering; deploying Bastion in a spoke breaks this.
// Standard SKU enables native client tunnelling (RDP/SSH via az CLI).
// ---------------------------------------------------------------------------
resource pipBastion 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: 'pip-${bastionName}-01'
  location: location
  tags: union(tags, { Function: 'Bastion' })
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
  zones: zoneEnabled ? zonesAll : null
}

resource bastion 'Microsoft.Network/bastionHosts@2023-06-01' = {
  name: bastionName
  location: location
  tags: union(tags, { Function: 'Bastion' })
  sku: { name: 'Standard' }
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          // Cross-RG reference to AzureBastionSubnet in the connectivity VNet
          subnet:          { id: bastionSubnetId }
          publicIPAddress: { id: pipBastion.id }
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output mgmtVnetId        string = mgmtVnet.id
output mgmtVmId          string = mgmtVm.id
output mgmtVmName        string = mgmtVm.name
output mgmtVmOsDiskId    string = mgmtVm.properties.storageProfile.osDisk.managedDisk.id
output bastionId         string = bastion.id
output routeTableId      string = routeTable.id

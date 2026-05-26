param natGateways_nat_gw_prod_core_connectivity_CUST_uksouth_01_name string = 'nat-gw-prod-core-connectivity-CUST-uksouth-01'
param virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name string = 'vnet-prod-core-connectivity-CUST-uksouth-01'
param networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name string = 'vnetmgr-prod-core-connectivity-CUST-uksouth-01'
param publicIPAddresses_pip_nat_gw_prod_core_connectivity_CUST_uksouth_01_name string = 'pip-nat-gw-prod-core-connectivity-CUST-uksouth-01'
param publicIPAddresses_pip_vnet_gw_prod_core_connectivity_CUST_uksouth_01_name string = 'pip-vnet-gw-prod-core-connectivity-CUST-uksouth-01'
param publicIPAddresses_pip_vnet_gw_prod_core_connectivity_CUST_uksouth_02_name string = 'pip-vnet-gw-prod-core-connectivity-CUST-uksouth-02'
param virtualNetworkGateways_vnet_gw_prod_core_connectivity_CUST_uksouth_01_name string = 'vnet-gw-prod-core-connectivity-CUST-uksouth-01'
param virtualNetworks_vnet_prod_core_management_CUST_uksouth_01_externalid string = '/subscriptions/da0cb90a-2204-40a3-9395-f1de2ce63803/resourceGroups/rg-prod-core-management-CUST-uksouth-01/providers/Microsoft.Network/virtualNetworks/vnet-prod-core-management-CUST-uksouth-01'
param virtualNetworks_vnet_prod_application_CUST_uksouth_01_externalid string = '/subscriptions/da0cb90a-2204-40a3-9395-f1de2ce63803/resourceGroups/rg-prod-application-CUST-uksouth-01/providers/Microsoft.Network/virtualNetworks/vnet-prod-application-CUST-uksouth-01'
param virtualNetworks_vnet_prod_sharedservices_CUST_uksouth_01_externalid string = '/subscriptions/da0cb90a-2204-40a3-9395-f1de2ce63803/resourceGroups/rg-prod-sharedservices-CUST-uksouth-01/providers/Microsoft.Network/virtualNetworks/vnet-prod-sharedservices-CUST-uksouth-01'
param virtualNetworks_vnet_prod_core_identity_CUST_uksouth_01_externalid string = '/subscriptions/da0cb90a-2204-40a3-9395-f1de2ce63803/resourceGroups/rg-prod-core-identity-CUST-uksouth-01/providers/Microsoft.Network/virtualNetworks/vnet-prod-core-identity-CUST-uksouth-01'
param virtualNetworks_vnet_prod_virtualdesktop_CUST_uksouth_01_externalid string = '/subscriptions/da0cb90a-2204-40a3-9395-f1de2ce63803/resourceGroups/rg-prod-virtualdesktop-CUST-uksouth-01/providers/Microsoft.Network/virtualNetworks/vnet-prod-virtualdesktop-CUST-uksouth-01'

resource networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_resource 'Microsoft.Network/networkManagers@2024-05-01' = {
  name: networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name
  location: 'uksouth'
  tags: {
    environment: 'Production'
    function: 'Core Connectivity'
    location: 'UK South'
    createdBy: 'Espria Ltd'
    managedBy: 'Espria Ltd'
    application: 'Connectivity and Routing'
    costCenter: 'Core Services'
  }
  properties: {
    networkManagerScopes: {
      managementGroups: []
      subscriptions: [
        '/subscriptions/da0cb90a-2204-40a3-9395-f1de2ce63803'
      ]
    }
    networkManagerScopeAccesses: [
      'Connectivity'
      'Routing'
    ]
  }
}

resource publicIPAddresses_pip_vnet_gw_prod_core_connectivity_CUST_uksouth_01_name_resource 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: publicIPAddresses_pip_vnet_gw_prod_core_connectivity_CUST_uksouth_01_name
  location: 'uksouth'
  tags: {
    Environment: 'Production'
    Function: 'Core Connectivity'
    Location: 'UK South'
    CreatedBy: 'Espria Ltd'
    ManagedBy: 'Espria Ltd'
    Application: 'Connectivity and Routing'
    CostCenter: 'Core Services'
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    ipAddress: '74.177.163.184'
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    ipTags: []
  }
}

resource publicIPAddresses_pip_vnet_gw_prod_core_connectivity_CUST_uksouth_02_name_resource 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: publicIPAddresses_pip_vnet_gw_prod_core_connectivity_CUST_uksouth_02_name
  location: 'uksouth'
  tags: {
    Environment: 'Production'
    Function: 'Core Connectivity'
    Location: 'UK South'
    CreatedBy: 'Espria Ltd'
    ManagedBy: 'Espria Ltd'
    Application: 'Connectivity and Routing'
    CostCenter: 'Core Services'
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    ipAddress: '131.145.99.232'
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    ipTags: []
  }
}

resource natGateways_nat_gw_prod_core_connectivity_CUST_uksouth_01_name_resource 'Microsoft.Network/natGateways@2024-05-01' = {
  name: natGateways_nat_gw_prod_core_connectivity_CUST_uksouth_01_name
  location: 'uksouth'
  tags: {
    Environment: 'Production'
    Function: 'Core Connectivity'
    Location: 'UK South'
    CreatedBy: 'Espria Ltd'
    ManagedBy: 'Espria Ltd'
    Application: 'Connectivity and Routing'
    CostCenter: 'Core Services'
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: [
    '1'
  ]
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: publicIPAddresses_pip_nat_gw_prod_core_connectivity_CUST_uksouth_01_name_resource.id
      }
    ]
  }
}

resource networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_spoke_networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name 'Microsoft.Network/networkManagers/networkGroups@2024-05-01' = {
  parent: networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_resource
  name: 'spoke-${networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name}'
  properties: {
    memberType: 'VirtualNetwork'
  }
}

resource publicIPAddresses_pip_nat_gw_prod_core_connectivity_CUST_uksouth_01_name_resource 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: publicIPAddresses_pip_nat_gw_prod_core_connectivity_CUST_uksouth_01_name
  location: 'uksouth'
  tags: {
    Environment: 'Production'
    Function: 'Core Connectivity'
    Location: 'UK South'
    CreatedBy: 'Espria Ltd'
    ManagedBy: 'Espria Ltd'
    Application: 'Connectivity and Routing'
    CostCenter: 'Core Services'
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: [
    '1'
  ]
  properties: {
    natGateway: {
      id: natGateways_nat_gw_prod_core_connectivity_CUST_uksouth_01_name_resource.id
    }
    ipAddress: '20.108.27.157'
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    ipTags: []
    ddosSettings: {
      protectionMode: 'VirtualNetworkInherited'
    }
  }
}

resource virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name_resource 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name
  location: 'uksouth'
  tags: {
    Environment: 'Production'
    Function: 'Core Connectivity'
    Location: 'UK South'
    CreatedBy: 'Espria Ltd'
    ManagedBy: 'Espria Ltd'
    Application: 'Connectivity and Routing'
    CostCenter: 'Core Services'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.101.0.0/21'
      ]
    }
    encryption: {
      enabled: false
      enforcement: 'AllowUnencrypted'
    }
    privateEndpointVNetPolicies: 'Disabled'
    subnets: [
      {
        name: 'GatewaySubnet'
        id: virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name_GatewaySubnet.id
        properties: {
          addressPrefixes: [
            '10.101.0.0/25'
          ]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: 'AzureFirewallSubnet'
        id: virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name_AzureFirewallSubnet.id
        properties: {
          addressPrefixes: [
            '10.101.0.128/26'
          ]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: 'PrivateEndpoint'
        id: virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name_PrivateEndpoint.id
        properties: {
          addressPrefixes: [
            '10.101.7.0/24'
          ]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: 'NATGatewaySubnet'
        id: virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name_NATGatewaySubnet.id
        properties: {
          addressPrefixes: [
            '10.101.0.192/26'
          ]
          natGateway: {
            id: natGateways_nat_gw_prod_core_connectivity_CUST_uksouth_01_name_resource.id
          }
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
    ]
    virtualNetworkPeerings: []
    enableDdosProtection: false
  }
}

resource virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name_AzureFirewallSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: '${virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name}/AzureFirewallSubnet'
  properties: {
    addressPrefixes: [
      '10.101.0.128/26'
    ]
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name_resource
  ]
}

resource virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name_GatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: '${virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name}/GatewaySubnet'
  properties: {
    addressPrefixes: [
      '10.101.0.0/25'
    ]
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name_resource
  ]
}

resource virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name_PrivateEndpoint 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: '${virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name}/PrivateEndpoint'
  properties: {
    addressPrefixes: [
      '10.101.7.0/24'
    ]
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name_resource
  ]
}

resource networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_spoke_networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_ANM_1izn4jirde 'Microsoft.Network/networkManagers/networkGroups/staticMembers@2024-05-01' = {
  parent: networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_spoke_networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name
  name: 'ANM_1izn4jirde'
  properties: {
    resourceId: virtualNetworks_vnet_prod_core_management_CUST_uksouth_01_externalid
  }
  dependsOn: [
    networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_resource
  ]
}

resource networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_spoke_networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_ANM_k14oui2wfe 'Microsoft.Network/networkManagers/networkGroups/staticMembers@2024-05-01' = {
  parent: networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_spoke_networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name
  name: 'ANM_k14oui2wfe'
  properties: {
    resourceId: virtualNetworks_vnet_prod_application_CUST_uksouth_01_externalid
  }
  dependsOn: [
    networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_resource
  ]
}

resource networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_spoke_networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_ANM_nd917jwl0b 'Microsoft.Network/networkManagers/networkGroups/staticMembers@2024-05-01' = {
  parent: networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_spoke_networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name
  name: 'ANM_nd917jwl0b'
  properties: {
    resourceId: virtualNetworks_vnet_prod_sharedservices_CUST_uksouth_01_externalid
  }
  dependsOn: [
    networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_resource
  ]
}

resource networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_spoke_networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_ANM_usa9rd0add 'Microsoft.Network/networkManagers/networkGroups/staticMembers@2024-05-01' = {
  parent: networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_spoke_networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name
  name: 'ANM_usa9rd0add'
  properties: {
    resourceId: virtualNetworks_vnet_prod_core_identity_CUST_uksouth_01_externalid
  }
  dependsOn: [
    networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_resource
  ]
}

resource networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_spoke_networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_ANM_xd4emwvche 'Microsoft.Network/networkManagers/networkGroups/staticMembers@2024-05-01' = {
  parent: networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_spoke_networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name
  name: 'ANM_xd4emwvche'
  properties: {
    resourceId: virtualNetworks_vnet_prod_virtualdesktop_CUST_uksouth_01_externalid
  }
  dependsOn: [
    networkManagers_vnetmgr_prod_core_connectivity_CUST_uksouth_01_name_resource
  ]
}

resource virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name_NATGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: '${virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name}/NATGatewaySubnet'
  properties: {
    addressPrefixes: [
      '10.101.0.192/26'
    ]
    natGateway: {
      id: natGateways_nat_gw_prod_core_connectivity_CUST_uksouth_01_name_resource.id
    }
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name_resource
  ]
}

resource virtualNetworkGateways_vnet_gw_prod_core_connectivity_CUST_uksouth_01_name_resource 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: virtualNetworkGateways_vnet_gw_prod_core_connectivity_CUST_uksouth_01_name
  location: 'uksouth'
  properties: {
    enablePrivateIpAddress: false
    ipConfigurations: [
      {
        name: 'default'
        id: '${virtualNetworkGateways_vnet_gw_prod_core_connectivity_CUST_uksouth_01_name_resource.id}/ipConfigurations/default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddresses_pip_vnet_gw_prod_core_connectivity_CUST_uksouth_01_name_resource.id
          }
          subnet: {
            id: virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name_GatewaySubnet.id
          }
        }
      }
      {
        name: 'activeActive'
        id: '${virtualNetworkGateways_vnet_gw_prod_core_connectivity_CUST_uksouth_01_name_resource.id}/ipConfigurations/activeActive'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddresses_pip_vnet_gw_prod_core_connectivity_CUST_uksouth_02_name_resource.id
          }
          subnet: {
            id: virtualNetworks_vnet_prod_core_connectivity_CUST_uksouth_01_name_GatewaySubnet.id
          }
        }
      }
    ]
    natRules: []
    virtualNetworkGatewayPolicyGroups: []
    enableBgpRouteTranslationForNat: false
    disableIPSecReplayProtection: false
    sku: {
      name: 'VpnGw2AZ'
      tier: 'VpnGw2AZ'
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    enableBgp: true
    activeActive: true
    bgpSettings: {
      asn: 65515
      bgpPeeringAddress: '10.101.0.5,10.101.0.4'
      peerWeight: 0
      bgpPeeringAddresses: [
        {
          ipconfigurationId: '${virtualNetworkGateways_vnet_gw_prod_core_connectivity_CUST_uksouth_01_name_resource.id}/ipConfigurations/default'
          customBgpIpAddresses: []
        }
        {
          ipconfigurationId: '${virtualNetworkGateways_vnet_gw_prod_core_connectivity_CUST_uksouth_01_name_resource.id}/ipConfigurations/activeActive'
          customBgpIpAddresses: []
        }
      ]
    }
    vpnGatewayGeneration: 'Generation2'
    allowRemoteVnetTraffic: false
    allowVirtualWanTraffic: false
  }
}

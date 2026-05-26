param bastionHosts_bastion_prod_core_management_CUST_uksouth_01_name string = 'bastion-prod-core-management-CUST-uksouth-01'
param virtualNetworks_vnet_prod_core_management_CUST_uksouth_01_name string = 'vnet-prod-core-management-CUST-uksouth-01'
param publicIPAddresses_pip_bastion_prod_core_management_CUST_uksouth_01_name string = 'pip-bastion-prod-core-management-CUST-uksouth-01'

resource publicIPAddresses_pip_bastion_prod_core_management_CUST_uksouth_01_name_resource 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: publicIPAddresses_pip_bastion_prod_core_management_CUST_uksouth_01_name
  location: 'uksouth'
  tags: {
    CreatedBy: 'Espria Ltd'
    Application: 'Azure Bastion'
    Function: 'Management Services'
    Location: 'UK South'
    Environment: 'Production'
  }
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: [
    '2'
    '1'
    '3'
  ]
  properties: {
    ipAddress: '131.145.122.178'
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    ipTags: []
  }
}

resource virtualNetworks_vnet_prod_core_management_CUST_uksouth_01_name_resource 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: virtualNetworks_vnet_prod_core_management_CUST_uksouth_01_name
  location: 'uksouth'
  tags: {
    CreatedBy: 'Espria Ltd'
    Application: 'Azure Bastion'
    Function: 'Management Services'
    Location: 'UK South'
    Environment: 'Production'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.101.248.0/21'
      ]
    }
    encryption: {
      enabled: false
      enforcement: 'AllowUnencrypted'
    }
    privateEndpointVNetPolicies: 'Disabled'
    subnets: [
      {
        name: 'ManagementEndpoints'
        id: virtualNetworks_vnet_prod_core_management_CUST_uksouth_01_name_ManagementEndpoints.id
        properties: {
          addressPrefixes: [
            '10.101.248.0/24'
          ]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: 'PrivateEndpoint'
        id: virtualNetworks_vnet_prod_core_management_CUST_uksouth_01_name_PrivateEndpoint.id
        properties: {
          addressPrefixes: [
            '10.101.255.0/24'
          ]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: 'AzureBastionSubnet'
        id: virtualNetworks_vnet_prod_core_management_CUST_uksouth_01_name_AzureBastionSubnet.id
        properties: {
          addressPrefixes: [
            '10.101.249.0/26'
          ]
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

resource virtualNetworks_vnet_prod_core_management_CUST_uksouth_01_name_AzureBastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: '${virtualNetworks_vnet_prod_core_management_CUST_uksouth_01_name}/AzureBastionSubnet'
  properties: {
    addressPrefixes: [
      '10.101.249.0/26'
    ]
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_vnet_prod_core_management_CUST_uksouth_01_name_resource
  ]
}

resource virtualNetworks_vnet_prod_core_management_CUST_uksouth_01_name_ManagementEndpoints 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: '${virtualNetworks_vnet_prod_core_management_CUST_uksouth_01_name}/ManagementEndpoints'
  properties: {
    addressPrefixes: [
      '10.101.248.0/24'
    ]
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_vnet_prod_core_management_CUST_uksouth_01_name_resource
  ]
}

resource virtualNetworks_vnet_prod_core_management_CUST_uksouth_01_name_PrivateEndpoint 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: '${virtualNetworks_vnet_prod_core_management_CUST_uksouth_01_name}/PrivateEndpoint'
  properties: {
    addressPrefixes: [
      '10.101.255.0/24'
    ]
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_vnet_prod_core_management_CUST_uksouth_01_name_resource
  ]
}

resource bastionHosts_bastion_prod_core_management_CUST_uksouth_01_name_resource 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: bastionHosts_bastion_prod_core_management_CUST_uksouth_01_name
  location: 'uksouth'
  tags: {
    CreatedBy: 'Espria Ltd'
    Application: 'Azure Bastion'
    Function: 'Management Services'
    Location: 'UK South'
    Environment: 'Production'
  }
  sku: {
    name: 'Standard'
  }
  zones: [
    '1'
    '2'
  ]
  properties: {
    dnsName: 'bst-2e418bdf-2afa-4b14-839f-08af26259a28.bastion.azure.com'
    scaleUnits: 2
    enableTunneling: false
    enableIpConnect: true
    disableCopyPaste: false
    enableShareableLink: false
    enableKerberos: true
    enableSessionRecording: false
    enablePrivateOnlyBastion: false
    ipConfigurations: [
      {
        name: 'IpConf'
        id: '${bastionHosts_bastion_prod_core_management_CUST_uksouth_01_name_resource.id}/bastionHostIpConfigurations/IpConf'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIPAddresses_pip_bastion_prod_core_management_CUST_uksouth_01_name_resource.id
          }
          subnet: {
            id: virtualNetworks_vnet_prod_core_management_CUST_uksouth_01_name_AzureBastionSubnet.id
          }
        }
      }
    ]
  }
}

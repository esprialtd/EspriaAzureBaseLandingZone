param virtualNetworks_vnet_prod_sharedservices_CUST_uksouth_01_name string = 'vnet-prod-sharedservices-CUST-uksouth-01'

resource virtualNetworks_vnet_prod_sharedservices_CUST_uksouth_01_name_resource 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: virtualNetworks_vnet_prod_sharedservices_CUST_uksouth_01_name
  location: 'uksouth'
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.101.16.0/21'
      ]
    }
    encryption: {
      enabled: false
      enforcement: 'AllowUnencrypted'
    }
    privateEndpointVNetPolicies: 'Disabled'
    subnets: [
      {
        name: 'SharedService'
        id: virtualNetworks_vnet_prod_sharedservices_CUST_uksouth_01_name_SharedService.id
        properties: {
          addressPrefixes: [
            '10.101.16.0/24'
          ]
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
        type: 'Microsoft.Network/virtualNetworks/subnets'
      }
      {
        name: 'PrivateEndpoint'
        id: virtualNetworks_vnet_prod_sharedservices_CUST_uksouth_01_name_PrivateEndpoint.id
        properties: {
          addressPrefixes: [
            '10.101.23.0/24'
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

resource virtualNetworks_vnet_prod_sharedservices_CUST_uksouth_01_name_PrivateEndpoint 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: '${virtualNetworks_vnet_prod_sharedservices_CUST_uksouth_01_name}/PrivateEndpoint'
  properties: {
    addressPrefixes: [
      '10.101.23.0/24'
    ]
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_vnet_prod_sharedservices_CUST_uksouth_01_name_resource
  ]
}

resource virtualNetworks_vnet_prod_sharedservices_CUST_uksouth_01_name_SharedService 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  name: '${virtualNetworks_vnet_prod_sharedservices_CUST_uksouth_01_name}/SharedService'
  properties: {
    addressPrefixes: [
      '10.101.16.0/24'
    ]
    delegations: []
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    virtualNetworks_vnet_prod_sharedservices_CUST_uksouth_01_name_resource
  ]
}

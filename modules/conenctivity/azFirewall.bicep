// modules/connectivity/azFirewall.bicep

@description('Customer abbreviation')
param customerAbbreviation string

@description('Azure region')
param region string

@description('Deployment environment')
param environment string

@description('CreatedBy tag')
param createdBy string

@description('ManagedBy tag')
param managedBy string

@description('Location tag')
param tagLocation string

@description('Firewall name')
param firewallName string = 'azfw-${environment}-core-connectivity-${customerAbbreviation}-${region}-01'

@description('AzureFirewallSubnet ID')
param firewallSubnetId string

resource firewall 'Microsoft.Network/azureFirewalls@2023-02-01' = {
  name: firewallName
  location: region
  tags: {
    CreatedBy: createdBy
    ManagedBy: managedBy
    Location: tagLocation
    Environment: environment
    Application: 'Connectivity and Routing'
    Function: 'Firewall'
    CostCenter: 'Core Services'
  }
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    ipConfigurations: [
      {
        name: 'azfw-config'
        properties: {
          subnet: {
            id: firewallSubnetId
          }
          publicIPAddress: null
        }
      }
    ]
  }
}

output firewallPrivateIpAddress string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallId string = firewall.id
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress

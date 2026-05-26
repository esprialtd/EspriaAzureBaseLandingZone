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

@description('Application tag')
param applicationTag string = 'Connectivity and Routing'

@description('Public IP name for VNet Gateway')
param publicIpName string = 'pip-azfw-${environment}-core-${customerAbbreviation}-${region}'

@description('Function tag') 
param functionTag string = 'Core Management'

@description('Cost Center tag')
param costCenterTag string = 'Core Services'

@description('Firewall name')
param firewallName string = 'azfw-${environment}-core-connectivity-${customerAbbreviation}-${region}-01'

@description('AzureFirewallSubnet ID')
param firewallSubnetId string

@description('Availability zones for Public IPs; specify at least one zone')
var availabilityZones array = [ '1', '2', '3' ]

// Create Public IP for Firewall
resource pip 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: publicIpName
  location: region
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  tags: {
    Application: applicationTag
    Function:    functionTag
    CostCenter:  costCenterTag
    CreatedBy:   createdBy
    ManagedBy:   managedBy
    Environment: environment
    Location:    tagLocation
  }
}

// Azure Firewall
resource firewall 'Microsoft.Network/azureFirewalls@2023-02-01' = {
  name: firewallName
  location: region
  dependsOn: [pip]
  tags: {
    Application: applicationTag
    Function: functionTag
    CostCenter: costCenterTag
    CreatedBy: createdBy
    ManagedBy: managedBy
    Environment: environment
    Location: tagLocation
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
          publicIPAddress: { id: pip.id }
        }
      }
    ]
  }
}

output firewallPrivateIpAddress string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallId string = firewall.id
output firewallPrivateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallPublicIpId string       = pip.id

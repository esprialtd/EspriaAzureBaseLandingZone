@description('Region')
param region string

@description('Name of the Bastion host')
param bastionName string

@description('Name of the virtual network')
param vnetName string

@description('Name of the AzureBastionSubnet')
param subnetName string = 'AzureBastionSubnet'

@description('Address prefix of the Bastion subnet')
param subnetPrefix string = '10.101.249.0/27'

@description('CreatedBy tag value')
param createdBy string

@description('ManagedBy tag value')
param managedBy string

@description('Environment tag value')
param environment string

@description('Location tag value for tags')
param tagLocation string

@description('Application tag value')
param applicationTag string = 'Remote Access'

@description('Function tag value')
param functionTag string = 'Bastion Host'

@description('CostCenter tag value')
param costCenterTag string = 'Core Management'

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-02-01' = {
  name: '${bastionName}-pip'
  location: region
  tags: {
    Application: applicationTag
    Function: functionTag
    CostCenter: costCenterTag
    CreatedBy: createdBy
    ManagedBy: managedBy
    Environment: environment
    Location: tagLocation
  }
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-02-01' = {
  name: '${vnetName}/${subnetName}'
  properties: {
    addressPrefix: subnetPrefix
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2023-02-01' = {
  name: bastionName
  location: region
  tags: {
    Application: applicationTag
    Function: functionTag
    CostCenter: costCenterTag
    CreatedBy: createdBy
    ManagedBy: managedBy
    Environment: environment
    Location: tagLocation
  }
  dependsOn: [
    bastionSubnet
    publicIp
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'bastionConfig'
        properties: {
          subnet: {
            id: bastionSubnet.id
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

output bastionId string = bastionHost.id

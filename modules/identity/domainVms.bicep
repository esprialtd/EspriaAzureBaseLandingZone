// modules/identity/domainVms.bicep

@description('Azure region')
param region string

@description('Region abbreviation (e.g., UKS)')
param regionAbbreviation string

@description('Customer abbreviation (e.g., ESP)')
param customerAbbreviation string

@description('Virtual network name')
param vnetName string

@description('Subnet name for domain controllers')
param subnetName string = 'DomainControllers'

@description('VM admin username')
param adminUsername string

@secure()
@description('VM admin password')
param adminPassword string

@description('VM size')
param vmSize string = 'Standard_D2s_v6'

@description('CreatedBy tag value')
param createdBy string

@description('ManagedBy tag value')
param managedBy string

@description('Environment tag value')
param environment string

@description('Location tag value for tags')
param tagLocation string

@description('Application tag value')
param applicationTag string = 'Domain Controller'

@description('Function tag value')
param functionTag string = 'Identity Services'

@description('CostCenter tag value')
param costCenterTag string = 'Core Services'

var zones = ['1', '2']

resource nic 'Microsoft.Network/networkInterfaces@2023-02-01' = [for i in range(0, 2): {
  name: '${customerAbbreviation}-AZ${regionAbbreviation}-DC0${i + 1}-nic'
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
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}]

resource vms 'Microsoft.Compute/virtualMachines@2023-03-01' = [for i in range(0, 2): {
  name: '${customerAbbreviation}-AZ${regionAbbreviation}-DC0${i + 1}'
  location: region
  zones: [zones[i]]
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
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${customerAbbreviation}-AZ${regionAbbreviation}-DC0${i + 1}'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer:     'WindowsServer'
        sku:       '2025-Datacenter-Gen2'
        version:   'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        diskSizeGB: 128
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic[i].id
        }
      ]
    }
  }
  dependsOn: [nic[i]]
}
]

output vmIds array = [for i in range(0, 2): vms[i].id]



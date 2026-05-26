@description('Name prefix for the VM')
param fsnamePrefix string

@description('VM size (must support Gen2 images)')
param vmSize string = 'Standard_D2s_v6'

@description('Region for the deployment')
param location string

@description('Virtual network name')
param vnetName string

@description('Subnet name for the VM')
param subnetName string = 'SharedServices'

@description('Admin username')
param adminUsername string

@description('Deployment environment')
param environment string

@secure()
@description('Admin password')
param adminPassword string

@description('CreatedBy tag value')
param createdBy string

@description('ManagedBy tag value')
param managedBy string

@description('Location tag value')
param tagLocation string

@description('Application tag')
param applicationTag string = 'Connectivity and Routing'

@description('Function tag') 
param functionTag string = 'Core Management'

@description('Cost Center tag')
param costCenterTag string = 'Core Services'

resource nic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: 'nic-${fsnamePrefix}'
  location: location
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
  tags: {
    Application: applicationTag
    Function: functionTag
    CostCenter: costCenterTag
    CreatedBy: createdBy
    ManagedBy: managedBy
    Environment: environment
    Location: tagLocation
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: fsnamePrefix
  location: location
  tags: {
    Application: applicationTag
    Function:    functionTag
    CostCenter:  costCenterTag
    CreatedBy:   createdBy
    ManagedBy:   managedBy
    Environment: environment
    Location:    tagLocation
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName:  fsnamePrefix
      adminUsername: adminUsername
      adminPassword: adminPassword
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
        managedDisk: {
          storageAccountType: 'Premium_ZRS'
        }
        diskSizeGB: 128
      }
    }
    networkProfile: {
      networkInterfaces: [ { id: nic.id } ]
    }
  }
}

output fileServerId string = vm.id

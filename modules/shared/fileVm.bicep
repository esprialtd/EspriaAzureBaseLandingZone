// modules/sharedservices/fileVm.bicep

@description('Name prefix for the VM')
param namePrefix string

@description('Region for the deployment')
param location string

@description('Virtual network name')
param vnetName string

@description('Subnet name for the VM')
param subnetName string = 'SharedServices'

@description('Admin username')
param adminUsername string

@secure()
@description('Admin password')
param adminPassword string

@description('Resource group for storage')
param storageRgName string

@description('CreatedBy tag value')
param createdBy string

@description('ManagedBy tag value')
param managedBy string

@description('Location tag value')
param tagLocation string

@description('customer abbreviation')
param customerAbbreviation string

@description('region')
param region string


resource nic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: '${namePrefix}-nic'
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
}

resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: '${namePrefix}-vm'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v6' // Adjust VM size as needed
    }
    osProfile: {
      computerName: '${namePrefix}-vm'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2025-Datacenter'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      dataDisks: [
        {
          lun: 0
          createOption: 'Empty'
          diskSizeGB: 1024
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

output vmId string = vm.id

// modules/management/managementVm.bicep

@description('Azure region')
param region string

@description('Customer abbreviation (e.g., ESP)')
param customerAbbreviation string

@description('Environment (e.g., prod, dev, uat)')
param environment string

@description('Virtual network name')
param vnetName string

@description('Subnet name for the management VM')
param subnetName string = 'ManagementServers'

@description('VM admin username')
param adminUsername string

@secure()
@description('VM admin password')
param adminPassword string

@description('CreatedBy tag value')
param createdBy string

@description('ManagedBy tag value')
param managedBy string

@description('Location tag value')
param tagLocation string

@description('Cost Center')
param costCenter string = 'Core Services'

@description('Application tag')
param applicationTag string = 'Management'

@description('Function tag')
param functionTag string = 'Administration'

resource nic 'Microsoft.Network/networkInterfaces@2023-02-01' = {
  name: '${customerAbbreviation}-${environment}-mgmt-nic'
  location: region
  tags: {
    Application: applicationTag
    Function: functionTag
    CostCenter: costCenter
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
}

resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: '${customerAbbreviation}-${environment}-mgmt-vm'
  location: region
  tags: {
    Application: applicationTag
    Function: functionTag
    CostCenter: costCenter
    CreatedBy: createdBy
    ManagedBy: managedBy
    Environment: environment
    Location: tagLocation
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v6'
    }
    osProfile: {
      computerName: '${customerAbbreviation}-${environment}-mgmt-vm'
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
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
  dependsOn: [
    nic
  ]
}

output managementServerId string = vm.id

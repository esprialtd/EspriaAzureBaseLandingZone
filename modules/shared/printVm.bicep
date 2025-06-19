// modules/sharedservices/printVm.bicep

@description('Name prefix for the Print Server VM')
param namePrefix string

@description('Azure region')
param location string

@description('Virtual Network name')
param vnetName string

@description('Subnet name for Print Server VM')
param subnetName string = 'SharedServices'

@description('Admin username for the VM')
param adminUsername string

@secure()
@description('Admin password for the VM')
param adminPassword string

@description('CreatedBy tag value')
param createdBy string

@description('ManagedBy tag value')
param managedBy string

@description('Environment tag value')
param environment string

@description('Location tag value')
param tagLocation string

@description('Application tag value')
param applicationTag string = 'Print Services'

@description('Function tag value')
param functionTag string = 'Print Server'

@description('CostCenter tag value')
param costCenterTag string = 'Shared Services'

@description('customer abbreviation')
param customerAbbreviation string

@description('region')
param region string

resource nic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: '${namePrefix}-nic'
  location: location
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
}

resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: '${namePrefix}-vm'
  location: location
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
      vmSize: 'Standard_D2s_v6'
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

resource printRoleExtension 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  name: '${vm.name}/InstallPrintRoles'
  location: location
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
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -Command "Install-WindowsFeature -Name Print-Server,Print-Services -IncludeManagementTools"'
    }
  }
  dependsOn: [
    vm
  ]
}

output vmId string = vm.id

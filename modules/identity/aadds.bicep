// modules/identity/aadds.bicep

@description('Azure region')
param region string

@description('Domain name for Entra Domain Services')
param domainName string

@description('Virtual Network name for integration')
param vnetName string

@description('Subnet name to associate with AAD DS')
param subnetName string = 'EntraDomainServices'

@description('CreatedBy tag value')
param createdBy string

@description('ManagedBy tag value')
param managedBy string

@description('Environment tag value')
param environment string

@description('Location tag value for tags (e.g., UK South)')
param tagLocation string

@description('Application tag value')
param applicationTag string = 'Entra Domain Services'

@description('Function tag value')
param functionTag string = 'Identity Services'

@description('CostCenter tag value')
param costCenterTag string = 'Core Services'

resource domainServices 'Microsoft.AAD/domainServices@2022-12-01' = {
  name: domainName
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
    domainName: domainName
    sku: 'Standard'
    replicaSets: [
      {
        location: region
        subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
      }
    ]
    ldapsSettings: {
      ldaps: 'Disabled' // Change to 'Enabled' if LDAPS is required
      pfxCertificate: '' // Replace with Key Vault reference if needed
      pfxCertificatePassword: '' // Replace with secure reference
    }
    notificationSettings: {
      notifyGlobalAdmins: 'true'
      notifyDcAdmins: 'true'
    }
    domainSecuritySettings: {
      tlsV1:           'Disabled'
      ntlmV1:          'Disabled'     
      ldapSigning:     'Enabled'      
      channelBinding:  'Enabled'
    }
  }
}

output aaddsId string = domainServices.id

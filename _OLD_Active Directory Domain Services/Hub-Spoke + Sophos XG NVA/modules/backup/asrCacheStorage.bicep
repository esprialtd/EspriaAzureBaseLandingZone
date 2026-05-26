// =============================================================================
// modules/backup/asrCacheStorage.bicep
// Cache storage account for Azure Site Recovery A2A replication.
// Must reside in the SOURCE region (primary connectivity RG).
// Used during replication to stage disk data before it is written
// to the managed disk replica in the target region.
// =============================================================================

param location string
param environment string
param customerAbbreviation string
param region string
param tags object

var custAbbr   = toLower(customerAbbreviation)
var regionAbbr = toLower(take(region, 3))
var env        = toLower(environment)

// Storage account names must be globally unique, ≤24 chars, lowercase alphanumeric
var storageAccountName = 'stasr${env}${custAbbr}${regionAbbr}01'

resource asrCacheStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: union(tags, { Function: 'ASR-Cache', Purpose: 'Site-Recovery-Staging' })
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion:       'TLS1_2'
    allowBlobPublicAccess:    false
    supportsHttpsTrafficOnly: true
    accessTier:              'Hot'
    networkAcls: {
      defaultAction: 'Allow'   // ASR requires outbound access; lockdown post-ASR if needed
    }
  }
}

output storageAccountId   string = asrCacheStorage.id
output storageAccountName string = asrCacheStorage.name

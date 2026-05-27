// =============================================================================
// modules/backup/asrReplication.bicep
// Azure Site Recovery – Management VM replication (primary → secondary)
//
// Architecture:
//   Source:  Primary management VM
//   Target:  Secondary region
//   Vault:   RSV in secondary management RG (ASR target vault)
//   Cache:   Storage account in primary connectivity RG
//
// ASR for IaaS VMs requires:
//   1. RSV in the TARGET region
//   2. Replication fabric (representing the source region as seen from target)
//   3. Replication protection container in each fabric
//   4. Container mapping between source and target containers
//   5. Cache storage account in the source region
//   6. Network mapping (source VNet → target VNet)
//   7. Replication policy (RPO + crash-consistent interval)
//   8. Replicated item (the actual VM)
//
// Scope: secondary management resource group
// =============================================================================

param location string                    // Secondary region location
param environment string
param customerAbbreviation string
param region string                      // Secondary region name (e.g. ukwest)
param primaryRegion string               // Primary region name (e.g. uksouth)
param tags object

// Source VM details
param sourceVmId string
param sourceVmName string
param sourceVmOsDiskId string
param sourceVmLocation string            // Primary region location

// Network IDs
param sourceMgmtVnetId string           // Primary management VNet
param targetMgmtVnetId string           // Secondary management VNet

// Cache storage account (pre-created in primary connectivity RG)
param cacheStorageAccountId string

var custAbbr = toUpper(customerAbbreviation)
var env      = environment
var priAbbr  = toUpper(take(primaryRegion, 3))
var secAbbr  = toUpper(take(region, 3))

var rsvAsrName = 'rsv-${env}-core-management-asr-${custAbbr}-${region}-01'

// ASR uses fabric names that are region display names
var sourceFabricName = '${primaryRegion}-fabric'
var targetFabricName = '${region}-fabric'
var sourceContainerName = '${primaryRegion}-container'
var targetContainerName = '${region}-container'
var mappingName         = '${primaryRegion}-to-${region}-mapping'
var policyName          = 'asr-policy-${env}-${custAbbr}-01'

// ---------------------------------------------------------------------------
// RSV for ASR (in secondary region – this is the recovery vault)
// ---------------------------------------------------------------------------
resource rsvAsr 'Microsoft.RecoveryServices/vaults@2023-06-01' = {
  name: rsvAsrName
  location: location
  tags: union(tags, { Function: 'ASR', Purpose: 'Site-Recovery-Vault' })
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    redundancySettings: {
      standardTierStorageRedundancy: 'GeoRedundant'
      crossRegionRestore:            'Enabled'
    }
    securitySettings: {
      softDeleteSettings: {
        softDeleteState:              'AlwaysON'
        softDeleteRetentionPeriodInDays: 14
      }
    }
    monitoringSettings: {
      azureMonitorAlertSettings: {
        alertsForAllJobFailures: 'Enabled'
      }
      classicAlertSettings: {
        alertsForCriticalOperations: 'Disabled'
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Replication Fabrics (source + target regions)
// ---------------------------------------------------------------------------
resource sourceFabric 'Microsoft.RecoveryServices/vaults/replicationFabrics@2023-06-01' = {
  parent: rsvAsr
  name: sourceFabricName
  properties: {
    customDetails: {
      instanceType: 'Azure'
      location:     sourceVmLocation
    }
  }
}

resource targetFabric 'Microsoft.RecoveryServices/vaults/replicationFabrics@2023-06-01' = {
  parent: rsvAsr
  name: targetFabricName
  properties: {
    customDetails: {
      instanceType: 'Azure'
      location:     location
    }
  }
}

// ---------------------------------------------------------------------------
// Protection Containers
// ---------------------------------------------------------------------------
resource sourceContainer 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers@2023-06-01' = {
  parent: sourceFabric
  name: sourceContainerName
  properties: {
    providerSpecificInput: [
      { instanceType: 'A2A' }
    ]
  }
}

resource targetContainer 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers@2023-06-01' = {
  parent: targetFabric
  name: targetContainerName
  properties: {
    providerSpecificInput: [
      { instanceType: 'A2A' }
    ]
  }
}

// ---------------------------------------------------------------------------
// Replication Policy
// RPO: 1 hour (3600 seconds)
// Crash-consistent snapshot: every 5 minutes
// App-consistent snapshot:   every 4 hours
// ---------------------------------------------------------------------------
resource replicationPolicy 'Microsoft.RecoveryServices/vaults/replicationPolicies@2023-06-01' = {
  parent: rsvAsr
  name: policyName
  properties: {
    providerSpecificInput: {
      instanceType:                     'A2A'
      recoveryPointHistory:             1440   // 24 hours of recovery points
      crashConsistentFrequencyInMinutes: 5
      appConsistentFrequencyInMinutes:   240   // 4 hours
      multiVmSyncStatus:               'Enable'
    }
  }
}

// ---------------------------------------------------------------------------
// Container Mapping (source → target, using the replication policy)
// ---------------------------------------------------------------------------
resource containerMapping 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers/replicationProtectionContainerMappings@2023-06-01' = {
  parent: sourceContainer
  name: mappingName
  properties: {
    targetProtectionContainerId: targetContainer.id
    policyId:                    replicationPolicy.id
    providerSpecificInput: {
      instanceType: 'A2A'
      agentAutoUpdateStatus: 'Enabled'
    }
  }
}

// ---------------------------------------------------------------------------
// Network Mapping (source management VNet → target management VNet)
// ---------------------------------------------------------------------------
resource networkMapping 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationNetworks/replicationNetworkMappings@2023-06-01' = {
  name: '${rsvAsrName}/${sourceFabricName}/azureNetwork/${primaryRegion}-to-${region}-netmapping'
  properties: {
    recoveryFabricName:   targetFabricName
    recoveryNetworkId:    targetMgmtVnetId
    fabricSpecificDetails: {
      instanceType:           'AzureToAzure'
      primaryNetworkId:       sourceMgmtVnetId
    }
  }
  dependsOn: [sourceFabric, targetFabric]
}

// ---------------------------------------------------------------------------
// Replicated Item – Management VM (A2A)
// Uses Managed Disk replication (no storage account needed for replica disks).
// ---------------------------------------------------------------------------
resource replicatedItem 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers/replicationProtectedItems@2023-06-01' = {
  parent: sourceContainer
  name: sourceVmName
  properties: {
    policyId:        replicationPolicy.id
    protectableItemId: ''
    providerSpecificDetails: {
      instanceType:              'A2A'
      fabricObjectId:            sourceVmId
      recoveryContainerId:       targetContainer.id
      recoveryResourceGroupId:   resourceGroup().id
      primaryStagingAzureStorageAccountId: cacheStorageAccountId
      vmDisks: []   // Empty = use managedDisks array instead
      vmManagedDisks: [
        {
          diskId:                           sourceVmOsDiskId
          recoveryResourceGroupId:          resourceGroup().id
          recoveryReplicaDiskAccountType:   'Premium_LRS'
          recoveryTargetDiskAccountType:    'Premium_LRS'
        }
      ]
      multiVmGroupName: '${sourceVmName}-asr-group'
    }
  }
  dependsOn: [containerMapping, networkMapping]
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output rsvAsrId              string = rsvAsr.id
output rsvAsrName            string = rsvAsr.name
output replicationPolicyId   string = replicationPolicy.id
output sourceFabricId        string = sourceFabric.id
output targetFabricId        string = targetFabric.id

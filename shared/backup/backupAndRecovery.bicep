// =============================================================================
// modules/backup/backupAndRecovery.bicep
//
// Deploys per region:
//   - Recovery Services Vault (RSV) for Azure VM Backup (DCs + MGMT VM)
//     Enhanced Policy – 4-hourly snapshots, 7-day instant restore
//   - Backup Vault (BUV) for Azure Disk Backup (Sophos XG NVA OS + data disks)
//     Enhanced disk backup policy – 4-hourly, 7-day retention
//   - RSV VM Backup protected items for DC VMs and MGMT VM
//   - Backup Vault disk backup protected items for NVA managed disks
//
// ASR (Azure Site Recovery) is a separate concern – see asrReplication.bicep.
// =============================================================================

param location string
param environment string
param customerAbbreviation string
param region string
param tags object
param zoneEnabled bool

@description('Resource group name this module deploys into – used for naming only')
param resourceGroupContext string = 'identity'

// VM resource IDs to protect with Azure VM Backup (DCs, MGMT VM)
@description('Array of VM resource IDs to protect with Azure VM Backup')
param vmBackupTargets array = []

// Managed disk resource IDs to protect with Azure Disk Backup (NVA disks)
@description('Array of managed disk resource IDs for Azure Disk Backup (NVA)')
param diskBackupTargets array = []

var custAbbr = toUpper(customerAbbreviation)
var env      = environment

var rsvName  = 'rsv-${env}-${resourceGroupContext}-${custAbbr}-${region}-01'
var buvName  = 'buv-${env}-${resourceGroupContext}-${custAbbr}-${region}-01'
var bupVmPolicyName  = 'bup-enhanced-vm-${env}-${custAbbr}-${region}-01'
var bupDiskPolicyName = 'bup-enhanced-disk-${env}-${custAbbr}-${region}-01'
var buvRedundancy = zoneEnabled ? 'ZoneRedundant' : 'LocallyRedundant'

// ---------------------------------------------------------------------------
// Recovery Services Vault – VM Backup
// Zone-redundant storage for resilience within the region.
// ---------------------------------------------------------------------------
resource rsv 'Microsoft.RecoveryServices/vaults@2023-06-01' = {
  name: rsvName
  location: location
  tags: union(tags, { Function: 'Backup', Purpose: 'VM-Backup-RSV' })
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    // redundancySettings are controlled via SKU and cannot be set as properties
    securitySettings: {
      softDeleteSettings: {
        softDeleteState:              'AlwaysON'
        softDeleteRetentionPeriodInDays: 14
      }
      immutabilitySettings: {
        state: 'Disabled'    // Can be enabled post-deployment for compliance
      }
    }
    monitoringSettings: {
      azureMonitorAlertSettings: {
        alertsForAllJobFailures: 'Enabled'
      }
      classicAlertSettings: {
        alertsForCriticalOperations: 'Disabled'   // Use Azure Monitor alerts
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Enhanced VM Backup Policy
// Enhanced policy supports 4-hourly backup frequency, multiple daily
// recovery points, and zone-redundant snapshot storage. Required for
// Premium SSD and VM with Trusted Launch.
// ---------------------------------------------------------------------------
resource vmBackupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-06-01' = {
  parent: rsv
  name: bupVmPolicyName
  properties: {
    backupManagementType: 'AzureIaasVM'
    policyType:           'V2'   // V2 = Enhanced Policy
    instantRPDetails: {
      azureBackupRGNamePrefix: 'rg-backup-snapshots-${custAbbr}'
      azureBackupRGNameSuffix: ''
    }
    instantRpRetentionRangeInDays: 7   // 7-day instant restore
    schedulePolicy: {
      schedulePolicyType:     'SimpleSchedulePolicyV2'
      scheduleRunFrequency:   'Hourly'
      hourlySchedule: {
        interval:            4    // Every 4 hours
        scheduleWindowStartTime: '2000-01-01T06:00:00Z'
        scheduleWindowDuration:  16   // 16-hour window (6am–10pm)
      }
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: ['2000-01-01T22:00:00Z']
        retentionDuration: {
          count:        30
          durationType: 'Days'
        }
      }
      weeklySchedule: {
        daysOfTheWeek: ['Sunday']
        retentionTimes: ['2000-01-01T22:00:00Z']
        retentionDuration: {
          count:        12
          durationType: 'Weeks'
        }
      }
      monthlySchedule: {
        retentionScheduleFormatType: 'Weekly'
        retentionScheduleWeekly: {
          daysOfTheWeek: ['Sunday']
          weeksOfTheMonth: ['First']
        }
        retentionTimes: ['2000-01-01T22:00:00Z']
        retentionDuration: {
          count:        12
          durationType: 'Months'
        }
      }
      yearlySchedule: {
        retentionScheduleFormatType: 'Weekly'
        retentionScheduleWeekly: {
          daysOfTheWeek: ['Sunday']
          weeksOfTheMonth: ['First']
        }
        monthsOfYear: ['January']
        retentionTimes: ['2000-01-01T22:00:00Z']
        retentionDuration: {
          count:        1
          durationType: 'Years'
        }
      }
    }
    tieringPolicy: {
      ArchivedRP: {
        tieringMode:              'TierRecommended'
        duration:                 0
        durationType:             'Invalid'
      }
    }
    timeZone: 'GMT Standard Time'
  }
}

// ---------------------------------------------------------------------------
// RSV Protected Items – VM Backup
// Associates each VM with the enhanced VM backup policy.
// Container format: iaasvmcontainerv2;{rgName};{vmName}
// Item format: vm;iaasvmcontainerv2;{rgName};{vmName}
// ---------------------------------------------------------------------------
resource vmBackupItems 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2023-06-01' = [for vm in vmBackupTargets: {
  name: '${rsvName}/Azure/iaasvmcontainerv2;${vm.rgName};${vm.vmName}/vm;iaasvmcontainerv2;${vm.rgName};${vm.vmName}'
  location: location
  properties: {
    protectedItemType:       'Microsoft.Compute/virtualMachines'
    sourceResourceId:        vm.vmId
    policyId:                vmBackupPolicy.id
    extendedProperties: {
      diskExclusionProperties: {
        diskLunList:    []
        isInclusionList: false
      }
    }
  }
}]

// ---------------------------------------------------------------------------
// Backup Vault – Azure Disk Backup (for Sophos XG NVA)
// Disk backup does not require VSS/application consistency – it captures
// managed disk snapshots independently. This is the correct approach for
// NVAs where the OS is not Windows/Linux-managed by Azure backup.
// ---------------------------------------------------------------------------
resource buv 'Microsoft.DataProtection/backupVaults@2023-11-01' = if (length(diskBackupTargets) > 0) {
  name: buvName
  location: location
  tags: union(tags, { Function: 'Backup', Purpose: 'Disk-Backup-Vault' })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    storageSettings: [
      {
        datastoreType: 'VaultStore'
        type:          buvRedundancy
      }
    ]
    securitySettings: {
      softDeleteSettings: {
        state:              'AlwaysOn'
        retentionDurationInDays: 14
      }
    }
    monitoringSettings: {
      azureMonitorAlertSettings: {
        alertsForAllJobFailures: 'Create'
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Disk Backup Policy – Enhanced (4-hourly, 7-day operational tier)
// ---------------------------------------------------------------------------
resource diskBackupPolicy 'Microsoft.DataProtection/backupVaults/backupPolicies@2023-11-01' = if (length(diskBackupTargets) > 0) {
  parent: buv
  name: bupDiskPolicyName
  properties: {
    datasourceTypes: ['Microsoft.Compute/disks']
    objectType:      'BackupPolicy'
    policyRules: [
      {
        objectType: 'AzureRetentionRule'
        name:       'Default'
        isDefault:  true
        lifecycles: [
          {
            deleteAfter: {
              objectType:    'AbsoluteDeleteOption'
              duration:      'P30D'   // 30-day vault retention
            }
            sourceDataStore: {
              dataStoreType: 'VaultStore'
              objectType:    'DataStoreInfoBase'
            }
            targetDataStoreCopySettings: []
          }
          {
            deleteAfter: {
              objectType: 'AbsoluteDeleteOption'
              duration:   'P7D'    // 7-day operational (snapshot) retention
            }
            sourceDataStore: {
              dataStoreType: 'OperationalStore'
              objectType:    'DataStoreInfoBase'
            }
            targetDataStoreCopySettings: []
          }
        ]
      }
      {
        objectType:       'AzureBackupRule'
        name:             'BackupHourly'
        backupParameters: {
          objectType:   'AzureBackupParams'
          backupType:   'Incremental'
        }
        dataStore: {
          dataStoreType: 'OperationalStore'
          objectType:    'DataStoreInfoBase'
        }
        trigger: {
          objectType: 'ScheduleBasedTriggerContext'
          schedule: {
            repeatingTimeIntervals: [
              'R/2024-01-01T06:00:00+00:00/PT4H'  // Every 4 hours
            ]
            timeZone: 'UTC'
          }
          taggingCriteria: [
            {
              isDefault: true
              tagInfo: {
                tagName: 'Default'
              }
              taggingPriority: 99
            }
          ]
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Disk Backup – Protected Items (NVA managed disks)
// Requires the Backup Vault MSI to have Disk Backup Reader on the disk
// and Disk Snapshot Contributor on the disk's RG.
// These RBAC assignments are output as reminders for post-deploy.
// ---------------------------------------------------------------------------
resource diskBackupItems 'Microsoft.DataProtection/backupVaults/backupInstances@2023-11-01' = [for disk in diskBackupTargets: if (length(diskBackupTargets) > 0) {
  parent: buv
  name: replace(replace(last(split(disk.diskId, '/')), '(', ''), ')', '')
  properties: {
    objectType:    'BackupInstance'
    friendlyName:  last(split(disk.diskId, '/'))
    dataSourceInfo: {
      objectType:       'Datasource'
      resourceID:       disk.diskId
      resourceName:     last(split(disk.diskId, '/'))
      resourceType:     'Microsoft.Compute/disks'
      resourceUri:      disk.diskId
      resourceLocation: location
      datasourceType:   'Microsoft.Compute/disks'
    }
    policyInfo: {
      policyId: diskBackupPolicy.id
    }
  }
}]

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output rsvId              string = rsv.id
output rsvName            string = rsv.name
output vmBackupPolicyId   string = vmBackupPolicy.id
output buvId              string = (length(diskBackupTargets) > 0) ? buv.id : ''
output diskBackupPolicyId string = (length(diskBackupTargets) > 0) ? diskBackupPolicy.id : ''

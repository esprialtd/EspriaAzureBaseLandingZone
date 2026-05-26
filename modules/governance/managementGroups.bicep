// =============================================================================
// modules/governance/managementGroups.bicep
// CAF-aligned management group hierarchy
// Scope: tenant() – deployed via az deployment tenant create
// =============================================================================
// Hierarchy:
//   Tenant Root Group
//   └── {CUST} Landing Zone                      (top-level)
//       ├── {CUST} Platform                      (platform subs: connectivity, identity, management)
//       │   ├── {CUST} Connectivity
//       │   ├── {CUST} Identity
//       │   └── {CUST} Management
//       └── {CUST} Landing Zones                 (workload LZs)
//           ├── {CUST} Corp                      (internal workloads)
//           └── {CUST} Online                    (internet-facing workloads)
// =============================================================================

targetScope = 'tenant'

@description('Customer full name (e.g., Contoso)')
param customerName string

@description('Customer abbreviation used as MG ID prefix (e.g., CON)')
param customerAbbreviation string

// Sanitised lower-case ID prefix (no spaces, no special chars)
var idPrefix = toLower(replace(customerAbbreviation, ' ', '-'))
var namePrefix = customerName

// ---------------------------------------------------------------------------
// Top-level Landing Zone group
// ---------------------------------------------------------------------------
resource mgLandingZone 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${idPrefix}-landing-zone'
  properties: {
    displayName: '${namePrefix} - Landing Zone'
  }
}

// ---------------------------------------------------------------------------
// Platform management group
// ---------------------------------------------------------------------------
resource mgPlatform 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${idPrefix}-platform'
  properties: {
    displayName: '${namePrefix} - Platform'
    details: {
      parent: {
        id: mgLandingZone.id
      }
    }
  }
}

resource mgConnectivity 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${idPrefix}-platform-connectivity'
  properties: {
    displayName: '${namePrefix} - Platform - Connectivity'
    details: {
      parent: {
        id: mgPlatform.id
      }
    }
  }
}

resource mgIdentity 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${idPrefix}-platform-identity'
  properties: {
    displayName: '${namePrefix} - Platform - Identity'
    details: {
      parent: {
        id: mgPlatform.id
      }
    }
  }
}

resource mgManagement 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${idPrefix}-platform-management'
  properties: {
    displayName: '${namePrefix} - Platform - Management'
    details: {
      parent: {
        id: mgPlatform.id
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Landing Zones group
// ---------------------------------------------------------------------------
resource mgLandingZones 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${idPrefix}-lzs'
  properties: {
    displayName: '${namePrefix} - Landing Zones'
    details: {
      parent: {
        id: mgLandingZone.id
      }
    }
  }
}

resource mgCorp 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${idPrefix}-lz-corp'
  properties: {
    displayName: '${namePrefix} - Corp'
    details: {
      parent: {
        id: mgLandingZones.id
      }
    }
  }
}

resource mgOnline 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${idPrefix}-lz-online'
  properties: {
    displayName: '${namePrefix} - Online'
    details: {
      parent: {
        id: mgLandingZones.id
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Sandbox / Decommissioned (CAF standard groups)
// ---------------------------------------------------------------------------
resource mgSandbox 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${idPrefix}-sandbox'
  properties: {
    displayName: '${namePrefix} - Sandbox'
    details: {
      parent: {
        id: mgLandingZone.id
      }
    }
  }
}

resource mgDecommissioned 'Microsoft.Management/managementGroups@2021-04-01' = {
  name: '${idPrefix}-decommissioned'
  properties: {
    displayName: '${namePrefix} - Decommissioned'
    details: {
      parent: {
        id: mgLandingZone.id
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output platformMgId        string = mgPlatform.id
output connectivityMgId    string = mgConnectivity.id
output identityMgId        string = mgIdentity.id
output managementMgId      string = mgManagement.id
output corpLzMgId          string = mgCorp.id
output onlineLzMgId        string = mgOnline.id

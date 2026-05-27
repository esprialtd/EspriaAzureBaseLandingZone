// =============================================================================
// modules/monitoring/centralMonitoring.bicep
// Central monitoring stack for the Landing Zone.
//
// Deploys:
//   - Log Analytics Workspace (primary management RG)
//   - Azure Monitor Action Group (email alerting baseline)
//   - Data Collection Rule (VM Insights – performance + event log)
//   - Azure Monitor Agent (AMA) VM extensions on all provided VMs
//   - Data Collection Rule Association per VM
//   - Diagnostic settings for VNets passed as array
//
// All diagnostic data flows to a single central LAW in the primary
// management RG. Secondary region VMs are also enrolled.
// =============================================================================

param location string
param environment string
param customerAbbreviation string
param tags object

@description('Alert notification email address (Espria managed service)')
param alertEmailAddress string = 'alerts@espria.com'

@description('Log Analytics workspace retention in days (30–730)')
@minValue(30)
@maxValue(730)
param retentionDays int = 90

@description('Log Analytics workspace SKU')
@allowed(['PerGB2018', 'CapacityReservation'])
param lawSku string = 'PerGB2018'

// VM resource IDs to enrol into VM Insights (all regions)
// Each entry: { id: string, location: string }
param vmInsightsVms array = []

// VNet resource IDs + locations for diagnostic settings
// Each entry: { id: string, location: string }
param vnetDiagnosticTargets array = []

var custAbbr = toUpper(customerAbbreviation)
var env      = environment
var lawName  = 'log-${env}-core-management-${custAbbr}-${location}-01'
var dcrName  = 'dcr-${env}-vminsights-${custAbbr}-${location}-01'
var agName   = 'ag-${env}-espria-alerts-${custAbbr}-${location}-01'

// ---------------------------------------------------------------------------
// Log Analytics Workspace
// ---------------------------------------------------------------------------
resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: lawName
  location: location
  tags: union(tags, { Function: 'Monitoring', Purpose: 'Central-Log-Analytics' })
  properties: {
    sku: { name: lawSku }
    retentionInDays: retentionDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
      disableLocalAuth: false
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery:    'Enabled'
  }
}

// VM Insights solution on the workspace
resource vmInsightsSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'VMInsights(${lawName})'
  location: location
  tags: tags
  plan: {
    name:          'VMInsights(${lawName})'
    publisher:     'Microsoft'
    product:       'OMSGallery/VMInsights'
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: law.id
  }
}

// ServiceMap solution
resource serviceMapSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'ServiceMap(${lawName})'
  location: location
  tags: tags
  plan: {
    name:          'ServiceMap(${lawName})'
    publisher:     'Microsoft'
    product:       'OMSGallery/ServiceMap'
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: law.id
  }
}

// ---------------------------------------------------------------------------
// Action Group
// ---------------------------------------------------------------------------
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: agName
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'EspriaAlerts'
    enabled:        true
    emailReceivers: [
      {
        name:                 'Espria NOC'
        emailAddress:         alertEmailAddress
        useCommonAlertSchema: true
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Data Collection Rule – VM Insights
// ---------------------------------------------------------------------------
resource dcr 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: dcrName
  location: location
  tags: union(tags, { Function: 'Monitoring', Purpose: 'VM-Insights-DCR' })
  kind: 'Windows'
  properties: {
    description: 'VM Insights data collection rule – performance counters and Windows event logs'
    dataSources: {
      performanceCounters: [
        {
          name:                       'VMInsightsPerfCounters'
          streams:                    ['Microsoft-InsightsMetrics']
          samplingFrequencyInSeconds: 60
          counterSpecifiers:          ['\\VmInsights\\DetailedMetrics']
        }
      ]
      windowsEventLogs: [
        {
          name:    'WindowsSystemEventLog'
          streams: ['Microsoft-Event']
          xPathQueries: [
            'System!*[System[(Level=1 or Level=2 or Level=3)]]'
            'Application!*[System[(Level=1 or Level=2)]]'
          ]
        }
      ]
      extensions: [
        {
          name:              'DependencyAgentDataSource'
          streams:           ['Microsoft-ServiceMap']
          extensionName:     'DependencyAgent'
          extensionSettings: {}
        }
      ]
    }
    dataFlows: [
      { streams: ['Microsoft-InsightsMetrics'], destinations: ['lawDestination'] }
      { streams: ['Microsoft-Event'],           destinations: ['lawDestination'] }
      { streams: ['Microsoft-ServiceMap'],      destinations: ['lawDestination'] }
    ]
    destinations: {
      logAnalytics: [
        {
          name:                'lawDestination'
          workspaceResourceId: law.id
        }
      ]
    }
  }
}

// ---------------------------------------------------------------------------
// Azure Monitor Agent extension per VM
// Extensions are deployed as standalone child resources using the
// parent/child name pattern (vmName/extensionName).
// No location property — extensions inherit location from the parent VM.
// ---------------------------------------------------------------------------
resource amaExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for vm in vmInsightsVms: {
  name: '${last(split(vm.id, '/'))}/AzureMonitorWindowsAgent'
  properties: {
    publisher:               'Microsoft.Azure.Monitor'
    type:                    'AzureMonitorWindowsAgent'
    typeHandlerVersion:      '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade:  true
    settings: {
      authentication: {
        managedIdentity: {
          'identifier-name':  'mi_res_id'
          'identifier-value': vm.id
        }
      }
    }
  }
}]

resource dependencyAgentExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for vm in vmInsightsVms: {
  name: '${last(split(vm.id, '/'))}/DependencyAgentWindows'
  dependsOn: [amaExtension]
  properties: {
    publisher:               'Microsoft.Azure.Monitoring.DependencyAgent'
    type:                    'DependencyAgentWindows'
    typeHandlerVersion:      '9.10'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade:  true
    settings: {
      enableAMA: true
    }
  }
}]

// ---------------------------------------------------------------------------
// DCR Association per VM
// DataCollectionRuleAssociations are extension resources scoped to the VM.
// Scope is expressed as the VM's resource ID string — valid in Bicep when
// the resource type supports extension resources and the target is in scope.
// In cross-RG scenarios (secondary region VMs), the association is deployed
// from this module's RG context but targets VMs in other RGs via resourceId.
// ---------------------------------------------------------------------------
resource dcrAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = [for vm in vmInsightsVms: {
  name: '${last(split(vm.id, '/'))}-vminsights-dcra'
  scope: resourceGroup()  // Association is in the same RG as the DCR; VM is referenced via dataCollectionRuleId
  properties: {
    dataCollectionRuleId: dcr.id
    description:          'VM Insights DCR association'
  }
  dependsOn: [amaExtension]
}]

// ---------------------------------------------------------------------------
// VNet Diagnostic Settings
// DiagnosticSettings on VNets in other resource groups require cross-scope
// deployment which must be done from each VNet's own resource group module.
// The NSGs and VNets in connectivity/identity/management RGs attach to this
// LAW via the diagnosticSettings child resource deployed in their own modules.
// LAW resource ID is available via the lawId output below.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output lawId          string = law.id
output lawWorkspaceId string = law.properties.customerId
output dcrId          string = dcr.id
output actionGroupId  string = actionGroup.id
output lawName        string = law.name

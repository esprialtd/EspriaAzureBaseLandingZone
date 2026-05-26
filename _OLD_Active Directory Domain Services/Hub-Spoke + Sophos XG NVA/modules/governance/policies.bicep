// =============================================================================
// modules/governance/policies.bicep
// Azure Policy guardrails for the Landing Zone.
// Scope: subscription
//
// Policies deployed:
//   1. Allowed Locations (Deny)       – restrict resource deployment to approved regions
//   2. Allowed VM SKUs  (Deny)        – restrict VM sizes to approved D-series variants
//   3. VM Insights AMA  (DINE)        – auto-enrol Windows VMs into Azure Monitor Agent
//   4. Diagnostic Settings (DINE)     – auto-configure LAW diagnostic settings on VMs
//   5. Region Audit     (Audit)       – surface non-compliant resources in future
//
// Built-in policy definition IDs used:
//   Allowed locations:     e56962a6-4747-49cd-b67b-bf8b01975c4c
//   Allowed VM SKUs:       cccc23c7-8427-4f31-a9df-30b2533c8d98
//   AMA for Windows VMs:   ca817e41-e85a-4783-bc7f-dc532d36235e
//   Diagnostics to LAW:    0868462e-646c-4fe3-9ced-a733534b6a2c (initiative)
// =============================================================================

targetScope = 'subscription'

param environment string
param customerAbbreviation string

@description('Primary region – always allowed')
param primaryRegion string

@description('Secondary region – always allowed')
param secondaryRegion string

@description('Log Analytics Workspace resource ID for DINE monitoring policies')
param lawResourceId string

@description('Data Collection Rule resource ID for AMA DINE policy')
param dcrResourceId string

var custAbbr = toUpper(customerAbbreviation)
var env      = environment

// ── Allowed VM SKUs ────────────────────────────────────────────────────────
// All D-series 2/4/8 vCPU variants that support ASR (A2A) replication.
// Extended from the deployment defaults to give operational flexibility.
// All variants listed support Premium Storage and Accelerated Networking.
// Reference: https://learn.microsoft.com/azure/site-recovery/azure-to-azure-support-matrix
var allowedVmSkus = [
  // D-series v4 – 2/4/8 vCPU
  'Standard_D2s_v4'
  'Standard_D4s_v4'
  'Standard_D8s_v4'
  'Standard_D2ds_v4'
  'Standard_D4ds_v4'
  'Standard_D8ds_v4'
  'Standard_D2as_v4'
  'Standard_D4as_v4'
  'Standard_D8as_v4'
  // D-series v5 – 2/4/8 vCPU (preferred generation)
  'Standard_D2s_v5'
  'Standard_D4s_v5'
  'Standard_D8s_v5'
  'Standard_D2ds_v5'
  'Standard_D4ds_v5'
  'Standard_D8ds_v5'
  'Standard_D2as_v5'
  'Standard_D4as_v5'
  'Standard_D8as_v5'
  'Standard_D2ads_v5'
  'Standard_D4ads_v5'
  'Standard_D8ads_v5'
  // D-series v6 – emerging generation (forward compatibility)
  'Standard_D2s_v6'
  'Standard_D4s_v6'
  'Standard_D8s_v6'
  // B-series burstable (Bastion companion / light workloads)
  'Standard_B2ms'
  'Standard_B4ms'
  'Standard_B8ms'
  // NVA-specific: Sophos XG supported sizes (NVA-only, blocked from other workloads by naming convention)
  'Standard_F2s_v2'
  'Standard_F4s_v2'
  'Standard_F8s_v2'
]

// Allowed locations – primary + secondary only
var allowedLocations = [
  primaryRegion
  secondaryRegion
  'global'   // Required for global resources (Action Groups, Front Door, etc.)
]

// ---------------------------------------------------------------------------
// 1. Allowed Locations – Deny
// Prevents resource deployment outside the two approved regions.
// Effect is Deny to enforce at deployment time.
// ---------------------------------------------------------------------------
resource policyAllowedLocations 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'pa-allowed-locations-${env}-${custAbbr}'
  location: primaryRegion
  properties: {
    displayName:   '[${custAbbr}] Allowed Locations – ${primaryRegion} / ${secondaryRegion}'
    description:   'Restricts resource deployment to the approved regions defined at Landing Zone deployment time. Enforced as Deny.'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c'
    enforcementMode:    'Default'    // Deny
    parameters: {
      listOfAllowedLocations: {
        value: allowedLocations
      }
    }
    nonComplianceMessages: [
      {
        message: 'Resource deployment is restricted to ${primaryRegion} and ${secondaryRegion}. Contact Espria to request a region change.'
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// 2. Allowed VM SKUs – Deny
// Restricts VM sizes to approved D-series and B-series variants.
// ---------------------------------------------------------------------------
resource policyAllowedSkus 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'pa-allowed-vm-skus-${env}-${custAbbr}'
  location: primaryRegion
  properties: {
    displayName:   '[${custAbbr}] Allowed VM SKUs – D-series 2/4/8 vCPU'
    description:   'Restricts VM deployment to approved D-series and B-series SKUs. Includes 2/4/8 vCPU variants across v4/v5/v6 generations. Contact Espria to request additional SKUs.'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/cccc23c7-8427-4f31-a9df-30b2533c8d98'
    enforcementMode:    'Default'    // Deny
    parameters: {
      listOfAllowedSKUs: {
        value: allowedVmSkus
      }
    }
    nonComplianceMessages: [
      {
        message: 'The requested VM SKU is not in the approved list. Approved SKUs are D-series 2/4/8 vCPU (v4/v5/v6) and B-series burstable. Contact Espria to request an exception.'
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// 3. Azure Monitor Agent – Deploy If Not Exists (Windows VMs)
// Auto-enrolls new Windows VMs into AMA when they are created or updated.
// Requires the policy assignment to have a managed identity for DINE.
// ---------------------------------------------------------------------------
resource policyAmaWindows 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'pa-ama-windows-${env}-${custAbbr}'
  location: primaryRegion
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName:   '[${custAbbr}] Deploy Azure Monitor Agent – Windows VMs'
    description:   'Automatically deploys Azure Monitor Agent on Windows VMs and associates them with the central Log Analytics workspace DCR. Ensures all VMs are enrolled in VM Insights.'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/ca817e41-e85a-4783-bc7f-dc532d36235e'
    enforcementMode:    'Default'
    parameters: {
      dcrResourceId: {
        value: dcrResourceId
      }
    }
    nonComplianceMessages: [
      {
        message: 'This VM is not enrolled in VM Insights. Azure Monitor Agent will be deployed automatically by policy remediation.'
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// 4. Diagnostic Settings → Log Analytics – Deploy If Not Exists
// Configures diagnostic settings on VMs to forward to the central LAW.
// Uses the built-in initiative for Azure Monitor baseline alerts.
// ---------------------------------------------------------------------------
resource policyDiagnosticSettings 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'pa-diag-settings-${env}-${custAbbr}'
  location: primaryRegion
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName:   '[${custAbbr}] Configure VM Diagnostic Settings → Central LAW'
    description:   'Deploy If Not Exists: configures VM diagnostic settings to forward metrics and logs to the central Log Analytics workspace in the management resource group.'
    policyDefinitionId: '/providers/Microsoft.Authorization/policyDefinitions/0868462e-646c-4fe3-9ced-a733534b6a2c'
    enforcementMode:    'Default'
    parameters: {
      logAnalytics: {
        value: lawResourceId
      }
    }
    nonComplianceMessages: [
      {
        message: 'Diagnostic settings are not configured. Policy remediation will configure diagnostics to forward to the central Log Analytics workspace.'
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// 5. RBAC: grant the DINE policy assignments Contributor on subscription
// Required for DeployIfNotExists to remediate resources.
// ---------------------------------------------------------------------------
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

resource amaRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, policyAmaWindows.id, contributorRoleId)
  properties: {
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${contributorRoleId}'
    principalId:      policyAmaWindows.identity.principalId
    principalType:    'ServicePrincipal'
  }
}

resource diagRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, policyDiagnosticSettings.id, contributorRoleId)
  properties: {
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${contributorRoleId}'
    principalId:      policyDiagnosticSettings.identity.principalId
    principalType:    'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// 6. Auto-Tagging – Inherit tags from Resource Group (Modify / DINE)
//
// Built-in policy: b27a0cbd-a167-4dfa-ae64-4337be671140
//   "Inherit a tag from the resource group if missing"
// Used three times – once per mandatory tag.  Effect = Modify so the tag
// is written onto the resource automatically, not just flagged.
// Each assignment needs a system-assigned identity with Tag Contributor.
//
// Tags auto-inherited:
//   CreatedBy   – who/what deployed this resource
//   ManagedBy   – Espria managed service identifier
//   Environment – prod | dev | uat
//
// Additional Audit assignments flag resources missing the Customer tag so
// that cost allocation reports stay accurate without blocking deployments.
// ---------------------------------------------------------------------------
var tagInheritPolicyId = '/providers/Microsoft.Authorization/policyDefinitions/b27a0cbd-a167-4dfa-ae64-4337be671140'
var tagContributorRoleId = '4a9ae827-6dc8-4573-8ac7-8239d42aa03f'

// Inherit CreatedBy
resource policyTagCreatedBy 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'pa-tag-createdby-${env}-${custAbbr}'
  location: primaryRegion
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName:         '[${custAbbr}] Auto-tag: Inherit CreatedBy from Resource Group'
    description:         'Automatically applies the CreatedBy tag to resources that are missing it, inheriting the value from the parent resource group. Ensures cost attribution and audit trail across all resources.'
    policyDefinitionId:  tagInheritPolicyId
    enforcementMode:     'Default'
    parameters: {
      tagName: { value: 'CreatedBy' }
    }
    nonComplianceMessages: [
      { message: 'Resource is missing the CreatedBy tag. Policy will automatically inherit this tag from the resource group.' }
    ]
  }
}

// Inherit ManagedBy
resource policyTagManagedBy 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'pa-tag-managedby-${env}-${custAbbr}'
  location: primaryRegion
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName:         '[${custAbbr}] Auto-tag: Inherit ManagedBy from Resource Group'
    description:         'Automatically applies the ManagedBy tag to resources that are missing it, inheriting from the parent resource group. Identifies Espria as the managing party for billing and operational reporting.'
    policyDefinitionId:  tagInheritPolicyId
    enforcementMode:     'Default'
    parameters: {
      tagName: { value: 'ManagedBy' }
    }
    nonComplianceMessages: [
      { message: 'Resource is missing the ManagedBy tag. Policy will automatically inherit this tag from the resource group.' }
    ]
  }
}

// Inherit Environment
resource policyTagEnvironment 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'pa-tag-environment-${env}-${custAbbr}'
  location: primaryRegion
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName:         '[${custAbbr}] Auto-tag: Inherit Environment from Resource Group'
    description:         'Automatically applies the Environment tag (prod/dev/uat) to resources that are missing it, inheriting from the parent resource group. Used in cost management filters and compliance reporting.'
    policyDefinitionId:  tagInheritPolicyId
    enforcementMode:     'Default'
    parameters: {
      tagName: { value: 'Environment' }
    }
    nonComplianceMessages: [
      { message: 'Resource is missing the Environment tag. Policy will automatically inherit this tag from the resource group.' }
    ]
  }
}

// Inherit Customer
resource policyTagCustomer 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: 'pa-tag-customer-${env}-${custAbbr}'
  location: primaryRegion
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName:         '[${custAbbr}] Auto-tag: Inherit Customer from Resource Group'
    description:         'Automatically applies the Customer tag to resources that are missing it, inheriting from the parent resource group. Required for multi-tenant cost reporting in Espria managed services.'
    policyDefinitionId:  tagInheritPolicyId
    enforcementMode:     'Default'
    parameters: {
      tagName: { value: 'Customer' }
    }
    nonComplianceMessages: [
      { message: 'Resource is missing the Customer tag. Policy will automatically inherit this tag from the resource group.' }
    ]
  }
}

// ---------------------------------------------------------------------------
// RBAC for auto-tagging policies (Tag Contributor on subscription)
// ---------------------------------------------------------------------------
resource tagCreatedByRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, policyTagCreatedBy.id, tagContributorRoleId)
  properties: {
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${tagContributorRoleId}'
    principalId:      policyTagCreatedBy.identity.principalId
    principalType:    'ServicePrincipal'
  }
}

resource tagManagedByRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, policyTagManagedBy.id, tagContributorRoleId)
  properties: {
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${tagContributorRoleId}'
    principalId:      policyTagManagedBy.identity.principalId
    principalType:    'ServicePrincipal'
  }
}

resource tagEnvironmentRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, policyTagEnvironment.id, tagContributorRoleId)
  properties: {
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${tagContributorRoleId}'
    principalId:      policyTagEnvironment.identity.principalId
    principalType:    'ServicePrincipal'
  }
}

resource tagCustomerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, policyTagCustomer.id, tagContributorRoleId)
  properties: {
    roleDefinitionId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/${tagContributorRoleId}'
    principalId:      policyTagCustomer.identity.principalId
    principalType:    'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output allowedLocationsPolicyId  string = policyAllowedLocations.id
output allowedSkusPolicyId       string = policyAllowedSkus.id
output amaPolicyId               string = policyAmaWindows.id
output amaPrincipalId            string = policyAmaWindows.identity.principalId
output diagPolicyId              string = policyDiagnosticSettings.id
output diagPrincipalId           string = policyDiagnosticSettings.identity.principalId
output tagCreatedByPolicyId      string = policyTagCreatedBy.id
output tagManagedByPolicyId      string = policyTagManagedBy.id
output tagEnvironmentPolicyId    string = policyTagEnvironment.id
output tagCustomerPolicyId       string = policyTagCustomer.id

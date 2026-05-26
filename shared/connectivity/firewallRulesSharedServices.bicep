// =============================================================================
// shared/connectivity/firewallRulesSharedServices.bicep
// Additional rule collection group for the Shared Services Landing Zone.
// Deployed SEPARATELY from the base policy — appends to the existing policy
// without modifying firewallPolicy.bicep.
//
// Invoke from the Shared Services LZ main.bicep:
//   module sharedSvcRules '../../shared/connectivity/firewallRulesSharedServices.bicep' = {
//     name: 'deploy-fw-rules-shared-services'
//     scope: resourceGroup(rgConnectivity)
//     params: {
//       firewallPolicyId:      coreConnectivity.outputs.firewallPolicyId
//       primarySiteOctet:      primaryRegionSiteId
//       secondarySiteOctet:    secondaryRegionSiteId
//       sharedServicesSiteOctet: sharedServicesSiteId
//       deploySecondaryRegion: deploySecondaryRegion
//       onPremAddressPrefix:   onPremAddressPrefix
//       tags:                  commonTags
//     }
//   }
//
// Priority 200 — sits between Platform-Core (100) and the Deny-All (65000).
// Add further workload groups at 300, 400, etc. using the same pattern.
// =============================================================================

@description('Resource ID of the existing Azure Firewall Policy to attach to.')
param firewallPolicyId string

param primarySiteOctet int
param secondarySiteOctet int = 0
param deploySecondaryRegion bool = true
param onPremAddressPrefix string = '10.1.0.0/16'

// Shared Services LZ site octet — this will be in the 10.x.16.0/21 range per Espria standards
// (vnet-prod-sharedservice-CUST-region-01 at 10.{siteId}.16.0/21)
@description('Site octet for the Shared Services LZ spoke VNet.')
param sharedServicesSiteOctet int

param tags object

// ---------------------------------------------------------------------------
// Subnet CIDRs
// Shared Services follows the Espria networking standard:
//   10.{siteId}.16.0/21  — Shared Services VNet (file, print, DFS, etc.)
//   10.{siteId}.16.0/24  — FileServices subnet
//   10.{siteId}.17.0/24  — PrintServices subnet
// ---------------------------------------------------------------------------
var priFileSubnet  = '10.${primarySiteOctet}.16.0/24'
var priPrintSubnet = '10.${primarySiteOctet}.17.0/24'
var priSvcVnet     = '10.${sharedServicesSiteOctet}.16.0/21'

var secFileSubnet  = '10.${secondarySiteOctet}.16.0/24'
var secPrintSubnet = '10.${secondarySiteOctet}.17.0/24'

var priMgmtSubnet  = '10.${primarySiteOctet}.248.0/21'
var secMgmtSubnet  = '10.${secondarySiteOctet}.248.0/21'
var priDcSubnet    = '10.${primarySiteOctet}.8.0/24'
var secDcSubnet    = '10.${secondarySiteOctet}.8.0/24'

var allFileSubnets  = deploySecondaryRegion ? [priFileSubnet, secFileSubnet]   : [priFileSubnet]
var allPrintSubnets = deploySecondaryRegion ? [priPrintSubnet, secPrintSubnet] : [priPrintSubnet]
var allMgmtSubnets  = deploySecondaryRegion ? [priMgmtSubnet, secMgmtSubnet]  : [priMgmtSubnet]
var allDcSubnets    = deploySecondaryRegion ? [priDcSubnet, secDcSubnet]       : [priDcSubnet]
var allSvcSources   = concat(allFileSubnets, allPrintSubnets)

// Reference the existing policy — no re-deployment
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-06-01' existing = {
  name: last(split(firewallPolicyId, '/'))
}

resource rcgSharedServices 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-06-01' = {
  parent: firewallPolicy
  name: 'RCG-SharedServices'
  properties: {
    priority: 200
    ruleCollections: [

      // ── SMB File Services ─────────────────────────────────────────────────
      // Client access to file shares from management and workload spokes.
      // Azure Files uses the same ports. DFS namespace resolution uses RPC.
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name:    'Allow-FileServices'
        priority: 100
        action: { type: 'Allow' }
        rules: [
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-SMB-File-Access'
            description:          'SMB file share access (TCP 445) from management and workload spokes to file servers'
            protocols:            ['TCP']
            sourceAddresses:      concat(allMgmtSubnets, [onPremAddressPrefix])
            destinationAddresses: allFileSubnets
            destinationPorts:     ['445']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-SMB-NetBIOS-File'
            description:          'NetBIOS for legacy SMB clients (TCP 139, UDP 137-138)'
            protocols:            ['UDP', 'TCP']
            sourceAddresses:      concat(allMgmtSubnets, [onPremAddressPrefix])
            destinationAddresses: allFileSubnets
            destinationPorts:     ['137', '138', '139']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-DFS-Namespace'
            description:          'DFS Namespace (TCP 80, 135, 445, 49152-65535) — for distributed file system resolution'
            protocols:            ['TCP']
            sourceAddresses:      concat(allMgmtSubnets, [onPremAddressPrefix])
            destinationAddresses: allFileSubnets
            destinationPorts:     ['80', '135', '445', '49152-65535']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-DFSR-Replication'
            description:          'DFSR replication between file servers (TCP 5722)'
            protocols:            ['TCP']
            sourceAddresses:      allFileSubnets
            destinationAddresses: allFileSubnets
            destinationPorts:     ['5722']
          }
        ]
      }

      // ── Print Services ────────────────────────────────────────────────────
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name:    'Allow-PrintServices'
        priority: 110
        action: { type: 'Allow' }
        rules: [
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-RPC-Spooler'
            description:          'Print Spooler RPC (TCP 135 + dynamic 49152-65535) — Windows print server'
            protocols:            ['TCP']
            sourceAddresses:      concat(allMgmtSubnets, [onPremAddressPrefix])
            destinationAddresses: allPrintSubnets
            destinationPorts:     ['135', '49152-65535']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-SMB-Print'
            description:          'SMB for print driver distribution and share access (TCP 445)'
            protocols:            ['TCP']
            sourceAddresses:      concat(allMgmtSubnets, [onPremAddressPrefix])
            destinationAddresses: allPrintSubnets
            destinationPorts:     ['445']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-LPR-LPD'
            description:          'LPR/LPD print protocol (TCP 515) for legacy Unix/Linux clients'
            protocols:            ['TCP']
            sourceAddresses:      concat(allMgmtSubnets, [onPremAddressPrefix])
            destinationAddresses: allPrintSubnets
            destinationPorts:     ['515']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-IPP-Print'
            description:          'IPP (TCP 631) — Internet Printing Protocol for modern clients'
            protocols:            ['TCP']
            sourceAddresses:      concat(allMgmtSubnets, [onPremAddressPrefix])
            destinationAddresses: allPrintSubnets
            destinationPorts:     ['631']
          }
        ]
      }

      // ── Shared Services → AD DS ───────────────────────────────────────────
      // File and print servers must authenticate against AD DS
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name:    'Allow-SharedSvc-To-ADDS'
        priority: 120
        action: { type: 'Allow' }
        rules: [
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-SharedSvc-AD-Auth'
            description:          'Shared Services servers to DCs: Kerberos, LDAP, RPC (required for domain-joined file/print servers)'
            protocols:            ['UDP', 'TCP']
            sourceAddresses:      allSvcSources
            destinationAddresses: allDcSubnets
            destinationPorts:     ['53', '88', '135', '389', '445', '636', '49152-65535']
          }
        ]
      }

      // ── Return traffic ────────────────────────────────────────────────────
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name:    'Allow-SharedSvc-Return'
        priority: 130
        action: { type: 'Allow' }
        rules: [
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-SharedSvc-Return-Traffic'
            description:          'Return traffic from file/print servers to clients'
            protocols:            ['UDP', 'TCP']
            sourceAddresses:      allSvcSources
            destinationAddresses: concat(allMgmtSubnets, [onPremAddressPrefix])
            destinationPorts:     ['*']
          }
        ]
      }

    ]
  }
}

output rcgId   string = rcgSharedServices.id
output rcgName string = rcgSharedServices.name

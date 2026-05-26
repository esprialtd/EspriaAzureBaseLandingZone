// =============================================================================
// shared/connectivity/firewallPolicy.bicep
// Azure Firewall Policy – shared module used by both Azure Firewall variants:
//   - variants/hub-azfw-vpngw  (AZFW_VNet)
//   - variants/vwan-azfw        (AZFW_Hub)
//
// Rule collection group priority layout:
//   100  RCG-Platform-Core       ADDS/Entra DS, DNS, Kerberos, LDAPS, SNMP, NetFlow/IPFIX
//   200  RCG-SharedServices      Deployed separately when Shared Services LZ added
//   300  RCG-Workloads           Deployed separately per workload LZ
//   500  RCG-Internet-Egress     Internet FQDN allow list (future)
//   65000 RCG-Deny-All           Explicit deny + log everything else
//
// Extensibility pattern:
//   This module owns RCG-Platform-Core and RCG-Deny-All.
//   Additional rule collection groups (Shared Services, Workload LZs) are
//   deployed as SEPARATE Bicep resources that parent: this policy by ID.
//   The calling module passes the policy ID as output; workload LZ modules
//   receive it as a parameter and deploy child ruleCollectionGroups against it.
//   No modification to this module is required to add new LZ rule sets.
//
//   Example for Shared Services LZ (file/print):
//     module sharedSvcRules '<repo-root>/shared/connectivity/firewallRulesSharedServices.bicep' = {
//       params: { firewallPolicyId: connectivity.outputs.firewallPolicyId, ... }
//     }
//
// Identity type param:
//   identityType = 'adds'    → full ADDS port set including RPC dynamic range
//   identityType = 'entrads' → managed domain subset (no RPC dynamic, no SYSVOL)
// =============================================================================

param location string
param environment string
param customerAbbreviation string

@description('Azure Firewall Policy SKU tier. Must match the Firewall it is attached to.')
@allowed(['Premium', 'Standard'])
param firewallSkuTier string = 'Premium'

@description('Identity type determines which ADDS/Entra DS rule set to deploy.')
@allowed(['adds', 'entrads'])
param identityType string = 'adds'

// Site octets — used to derive subnet CIDRs for precise source/destination scoping.
// Using exact subnets rather than 10.0.0.0/8 ensures rules are tight and auditable.
@description('Primary region site ID (2nd octet of 10.x.0.0/16)')
param primarySiteOctet int

@description('Secondary region site ID (2nd octet of 10.x.0.0/16). Pass 0 if secondary not deployed.')
param secondarySiteOctet int = 0

@description('On-premises address prefix for site-to-site traffic')
param onPremAddressPrefix string = '10.1.0.0/16'

@description('Deploy secondary region rules. Set false if secondary not deployed.')
param deploySecondaryRegion bool = true

param tags object

var custAbbr = toUpper(customerAbbreviation)
var env      = environment

var fwPolicyName = 'fwpol-${env}-core-${custAbbr}-${location}-01'

// ---------------------------------------------------------------------------
// Subnet CIDRs derived from site octets
// Matching the address space layout from the Espria networking standards:
//   Connectivity/Hub : 10.x.0.0/21  (or 10.x.0.0/23 for vWAN)
//   Identity spoke   : 10.x.8.0/22  → DomainControllers/EntraDomainServices at .8.0/24
//   Management spoke : 10.x.248.0/21
// ---------------------------------------------------------------------------
// Primary region
var priDcSubnet   = '10.${primarySiteOctet}.8.0/24'      // DomainControllers / EntraDomainServices
var priMgmtSubnet = '10.${primarySiteOctet}.248.0/21'     // Management spoke (entire range)
var priConnSubnet = '10.${primarySiteOctet}.0.0/21'       // Connectivity hub VNet (or vWAN hub range)

// Secondary region (only used when deploySecondaryRegion = true)
var secDcSubnet   = '10.${secondarySiteOctet}.8.0/24'
var secMgmtSubnet = '10.${secondarySiteOctet}.248.0/21'
var secConnSubnet = '10.${secondarySiteOctet}.0.0/21'

// All identity subnets (primary always; secondary conditional)
var allIdentitySubnets = deploySecondaryRegion
  ? [priDcSubnet, secDcSubnet]
  : [priDcSubnet]

// All management subnets
var allMgmtSubnets = deploySecondaryRegion
  ? [priMgmtSubnet, secMgmtSubnet]
  : [priMgmtSubnet]

// All connectivity subnets (source for SNMP poll)
var allConnSubnets = deploySecondaryRegion
  ? [priConnSubnet, secConnSubnet]
  : [priConnSubnet]

// Combined hub subnets (management + connectivity) — sources for ADDS traffic
var hubSources = concat(allMgmtSubnets, allConnSubnets)

// ---------------------------------------------------------------------------
// Azure Firewall Policy
// ---------------------------------------------------------------------------
resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-06-01' = {
  name: fwPolicyName
  location: location
  tags: union(tags, { Function: 'Hub-Connectivity', Purpose: 'Firewall-Policy' })
  properties: {
    sku: { tier: firewallSkuTier }
    threatIntelMode: 'Alert'
    insights: {
      isEnabled:    true
      retentionDays: 30
    }
    dnsSettings: {
      enableProxy: true
      // DNS proxy intercepts DNS queries from spoke VMs and forwards to DCs
      // This is required for correct ADDS domain resolution through the firewall
    }
  }
}

// ---------------------------------------------------------------------------
// RCG-Platform-Core  (priority 100)
// Contains all rules for the core Landing Zone:
//   - DNS from all spokes to DCs
//   - AD DS authentication and replication traffic
//   - SNMP from connectivity to management
//   - NTP for DCs
//   - On-premises to identity/management (for AD replication across VPN)
//   - Internet egress for Microsoft update endpoints (DCs and management)
// ---------------------------------------------------------------------------
resource rcgPlatformCore 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-06-01' = {
  parent: firewallPolicy
  name: 'RCG-Platform-Core'
  properties: {
    priority: 100
    ruleCollections: [

      // ── DNS ──────────────────────────────────────────────────────────────
      // All spokes query the Domain Controllers for DNS.
      // The Firewall DNS proxy intercepts on port 53 and forwards here.
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name:    'Allow-DNS'
        priority: 100
        action: { type: 'Allow' }
        rules: [
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-DNS-To-DCs'
            description:          'All spokes to Domain Controllers: DNS resolution (UDP+TCP 53)'
            protocols:            ['UDP', 'TCP']
            sourceAddresses:      hubSources
            destinationAddresses: allIdentitySubnets
            destinationPorts:     ['53']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-DNS-Reply'
            description:          'Domain Controllers DNS replies back to spokes'
            protocols:            ['UDP', 'TCP']
            sourceAddresses:      allIdentitySubnets
            destinationAddresses: hubSources
            destinationPorts:     ['53']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-DNS-OnPrem'
            description:          'On-premises DNS queries to DCs (conditional forwarder scenarios)'
            protocols:            ['UDP', 'TCP']
            sourceAddresses:      [onPremAddressPrefix]
            destinationAddresses: allIdentitySubnets
            destinationPorts:     ['53']
          }
        ]
      }

      // ── AD DS Core Authentication ────────────────────────────────────────
      // Kerberos, LDAP, LDAPS, and Global Catalog.
      // Sources: management spoke + connectivity/hub (for NVA and Bastion),
      //          on-premises (for hybrid AD scenarios).
      // Entra DS uses the same ports — LDAP/LDAPS/Kerberos apply to both.
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name:    'Allow-ADDS-Authentication'
        priority: 110
        action: { type: 'Allow' }
        rules: [
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-Kerberos'
            description:          'Kerberos authentication (UDP+TCP 88)'
            protocols:            ['UDP', 'TCP']
            sourceAddresses:      concat(hubSources, [onPremAddressPrefix])
            destinationAddresses: allIdentitySubnets
            destinationPorts:     ['88']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-LDAP'
            description:          'LDAP directory queries (UDP+TCP 389)'
            protocols:            ['UDP', 'TCP']
            sourceAddresses:      concat(hubSources, [onPremAddressPrefix])
            destinationAddresses: allIdentitySubnets
            destinationPorts:     ['389']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-LDAPS'
            description:          'LDAP over SSL (TCP 636) — required for secure LDAP binding'
            protocols:            ['TCP']
            sourceAddresses:      concat(hubSources, [onPremAddressPrefix])
            destinationAddresses: allIdentitySubnets
            destinationPorts:     ['636']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-GlobalCatalog-LDAP'
            description:          'Global Catalog LDAP (TCP 3268) — required for multi-domain forests'
            protocols:            ['TCP']
            sourceAddresses:      concat(hubSources, [onPremAddressPrefix])
            destinationAddresses: allIdentitySubnets
            destinationPorts:     ['3268']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-GlobalCatalog-LDAPS'
            description:          'Global Catalog LDAP over SSL (TCP 3269)'
            protocols:            ['TCP']
            sourceAddresses:      concat(hubSources, [onPremAddressPrefix])
            destinationAddresses: allIdentitySubnets
            destinationPorts:     ['3269']
          }
        ]
      }

      // ── AD DS RPC / Replication (ADDS only) ──────────────────────────────
      // RPC Endpoint Mapper and dynamic RPC ports are required for:
      //   - DC-to-DC AD replication
      //   - Group Policy application
      //   - NETLOGON, NTFRS, DFSR
      // Entra DS is a managed service — these ports are not required from client subnets.
      // The dynamic port range (49152–65535) is wide; in a hardened environment
      // you can restrict this further using registry-locked RPC ports on DCs.
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name:    identityType == 'adds' ? 'Allow-ADDS-RPC' : 'Allow-EntraDS-NTP'
        priority: 120
        action: { type: 'Allow' }
        rules: identityType == 'adds' ? [
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-RPC-Endpoint-Mapper'
            description:          'RPC Endpoint Mapper (TCP 135) — required for AD replication and GPO'
            protocols:            ['TCP']
            sourceAddresses:      concat(hubSources, [onPremAddressPrefix])
            destinationAddresses: allIdentitySubnets
            destinationPorts:     ['135']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-RPC-Dynamic'
            description:          'RPC dynamic port range (TCP 49152-65535) — AD replication, NETLOGON, DFSR. Restrict further with RPC port locking on DCs in hardened environments.'
            protocols:            ['TCP']
            sourceAddresses:      concat(hubSources, [onPremAddressPrefix])
            destinationAddresses: allIdentitySubnets
            destinationPorts:     ['49152-65535']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-SMB-SYSVOL-NETLOGON'
            description:          'SMB (TCP 445) for SYSVOL and NETLOGON share access — Group Policy, scripts'
            protocols:            ['TCP']
            sourceAddresses:      concat(hubSources, [onPremAddressPrefix])
            destinationAddresses: allIdentitySubnets
            destinationPorts:     ['445']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-NetBIOS'
            description:          'NetBIOS name resolution and session (UDP 137-138, TCP 139) — legacy clients'
            protocols:            ['UDP', 'TCP']
            sourceAddresses:      concat(hubSources, [onPremAddressPrefix])
            destinationAddresses: allIdentitySubnets
            destinationPorts:     ['137', '138', '139']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-DFSR'
            description:          'DFSR (TCP 5722) — DFS Replication for SYSVOL (Windows Server 2008+)'
            protocols:            ['TCP']
            sourceAddresses:      allIdentitySubnets   // DC-to-DC replication
            destinationAddresses: allIdentitySubnets
            destinationPorts:     ['5722']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-NTP-From-DCs'
            description:          'NTP (UDP 123) — DCs as authoritative time source for domain members'
            protocols:            ['UDP']
            sourceAddresses:      concat(hubSources, [onPremAddressPrefix])
            destinationAddresses: allIdentitySubnets
            destinationPorts:     ['123']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-DC-Replication-Outbound'
            description:          'Allow DCs to initiate replication to other DCs (includes secondary region)'
            protocols:            ['TCP']
            sourceAddresses:      allIdentitySubnets
            destinationAddresses: allIdentitySubnets
            destinationPorts:     ['135', '389', '636', '3268', '3269', '445', '49152-65535']
          }
        ] : [
          // Entra DS only needs NTP and management-plane HTTPS (handled by NSG — Azure to managed domain)
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-NTP-EntraDS'
            description:          'NTP (UDP 123) — managed domain time synchronisation'
            protocols:            ['UDP']
            sourceAddresses:      concat(hubSources, [onPremAddressPrefix])
            destinationAddresses: allIdentitySubnets
            destinationPorts:     ['123']
          }
        ]
      }

      // ── Kerberos / LDAP Return Traffic ───────────────────────────────────
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name:    'Allow-ADDS-Return'
        priority: 130
        action: { type: 'Allow' }
        rules: [
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-ADDS-Return-To-Clients'
            description:          'Return traffic from DCs back to management and connectivity spokes'
            protocols:            ['UDP', 'TCP']
            sourceAddresses:      allIdentitySubnets
            destinationAddresses: hubSources
            destinationPorts:     ['*']
          }
        ]
      }

      // ── SNMP ─────────────────────────────────────────────────────────────
      // Connectivity subnet (NVA, gateway devices) → Management subnet.
      // SNMP v2c/v3 polling: connectivity polls management devices (switches,
      // Bastion metrics, etc.) and management polls NVA health.
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name:    'Allow-SNMP'
        priority: 140
        action: { type: 'Allow' }
        rules: [
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-SNMP-Poll-Conn-To-Mgmt'
            description:          'SNMP polling (UDP 161) from connectivity subnet to management subnet — NVA and device health'
            protocols:            ['UDP']
            sourceAddresses:      allConnSubnets
            destinationAddresses: allMgmtSubnets
            destinationPorts:     ['161']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-SNMP-Trap-Mgmt-To-Conn'
            description:          'SNMP traps (UDP 162) from management to connectivity — alerts from managed devices'
            protocols:            ['UDP']
            sourceAddresses:      allMgmtSubnets
            destinationAddresses: allConnSubnets
            destinationPorts:     ['162']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-SNMP-Poll-Mgmt-To-Conn'
            description:          'SNMP polling (UDP 161) from management to connectivity — management VM polls NVA/firewall health'
            protocols:            ['UDP']
            sourceAddresses:      allMgmtSubnets
            destinationAddresses: allConnSubnets
            destinationPorts:     ['161']
          }
        ]
      }

      // ── NetFlow / IPFIX ──────────────────────────────────────────────────
      // NetFlow v5/v9 and IPFIX flow export from the management network.
      // Standard ports:
      //   UDP 2055 – NetFlow v5/v9 (Cisco standard, most collectors)
      //   UDP 4739 – IPFIX (RFC 7011 standard port)
      //   UDP 9996 – NetFlow legacy alternative (some NVA platforms)
      //   UDP 6343 – sFlow (for future sFlow-capable devices)
      // Source: connectivity subnet (NVA, flow exporters)
      // Destination: management subnet (collector on MGMT VM or dedicated VM)
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name:    'Allow-NetFlow'
        priority: 145
        action: { type: 'Allow' }
        rules: [
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-NetFlow-Conn-To-Mgmt'
            description:          'NetFlow v5/v9 (UDP 2055) and IPFIX (UDP 4739) from connectivity devices to management collector'
            protocols:            ['UDP']
            sourceAddresses:      allConnSubnets
            destinationAddresses: allMgmtSubnets
            destinationPorts:     ['2055', '4739']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-NetFlow-Legacy-Port'
            description:          'NetFlow legacy port UDP 9996 — some NVA platforms default to this'
            protocols:            ['UDP']
            sourceAddresses:      allConnSubnets
            destinationAddresses: allMgmtSubnets
            destinationPorts:     ['9996']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-sFlow-Conn-To-Mgmt'
            description:          'sFlow UDP 6343 from connectivity subnet to management collector'
            protocols:            ['UDP']
            sourceAddresses:      allConnSubnets
            destinationAddresses: allMgmtSubnets
            destinationPorts:     ['6343']
          }
          {
            ruleType:             'NetworkRule'
            name:                 'Allow-NetFlow-Mgmt-Internal'
            description:          'NetFlow collector intra-management traffic — collector acknowledgements and internal flow data'
            protocols:            ['UDP']
            sourceAddresses:      allMgmtSubnets
            destinationAddresses: allMgmtSubnets
            destinationPorts:     ['2055', '4739', '9996']
          }
        ]
      }

      // ── Microsoft Update / Windows Update (DCs and MGMT VMs) ─────────────
      // Azure-hosted Windows Update endpoints use HTTPS over the internet.
      // Rule allows DCs and MGMT VMs to reach Windows Update FQDNs.
      // Azure Update Manager (NinjaOne/Intune) uses the same endpoint.
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name:    'Allow-WindowsUpdate'
        priority: 150
        action: { type: 'Allow' }
        rules: [
          {
            ruleType:         'ApplicationRule'
            name:             'Allow-WindowsUpdate-DCs'
            description:      'Windows Update and Microsoft Update for Domain Controllers and MGMT VMs'
            protocols:        [{ protocolType: 'Https', port: 443 }]
            sourceAddresses:  concat(allIdentitySubnets, allMgmtSubnets)
            targetFqdns: [
              '*.update.microsoft.com'
              'update.microsoft.com'
              '*.windowsupdate.com'
              'windowsupdate.com'
              '*.download.windowsupdate.com'
              'download.windowsupdate.com'
              '*.delivery.mp.microsoft.com'
              'go.microsoft.com'
              '*.microsoft.com'
              'login.microsoftonline.com'
              '*.azure.com'
            ]
          }
          {
            ruleType:         'ApplicationRule'
            name:             'Allow-NTP-Time-Windows'
            description:      'Windows Time Service NTP to time.windows.com'
            protocols:        [{ protocolType: 'Http', port: 80 }]
            sourceAddresses:  concat(allIdentitySubnets, allMgmtSubnets)
            targetFqdns:      ['time.windows.com']
          }
        ]
      }

    ]  // end ruleCollections
  }  // end properties
}

// ---------------------------------------------------------------------------
// RCG-Deny-All  (priority 65000)
// Explicit deny with logging. Catches everything not matched above.
// Log-only initially — change action to 'Deny' when all required traffic
// is confirmed allowed and tested. Keep as final safety net.
// ---------------------------------------------------------------------------
resource rcgDenyAll 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-06-01' = {
  parent: firewallPolicy
  name: 'RCG-Deny-All'
  properties: {
    priority: 65000
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name:    'Deny-All-Inbound'
        priority: 100
        action: { type: 'Deny' }
        rules: [
          {
            ruleType:             'NetworkRule'
            name:                 'Deny-All-Internal'
            description:          'Catch-all deny for any internal traffic not explicitly allowed. Review firewall logs before tightening.'
            protocols:            ['Any']
            sourceAddresses:      ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']
            destinationAddresses: ['10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16']
            destinationPorts:     ['*']
          }
        ]
      }
    ]
  }
  dependsOn: [rcgPlatformCore]
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output firewallPolicyId   string = firewallPolicy.id
output firewallPolicyName string = firewallPolicy.name
// Expose the RCG IDs for dependency ordering in workload LZ modules
output coreRcgId          string = rcgPlatformCore.id
output denyAllRcgId       string = rcgDenyAll.id

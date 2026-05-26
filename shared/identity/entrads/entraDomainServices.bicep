// =============================================================================
// shared/identity/entrads/entraDomainServices.bicep
// Microsoft Entra Domain Services (formerly Azure AD DS) – Identity Module
//
// STATUS: Placeholder for future Entra DS variants.
// When ADDS variants are branched to Entra DS versions, this module replaces
// shared/identity/adds/identityVnet.bicep in the respective main.bicep files.
//
// Design Decisions vs IaaS ADDS (recorded for future implementation):
//
// 1. MANAGED SERVICE – no VM administration required.
//    Entra DS is a fully managed PaaS identity service. No DC VMs to patch,
//    backup, or manage. Authentication, Group Policy, LDAP, and Kerberos are
//    provided by Microsoft.
//
// 2. SINGLE-REGION – Entra DS does not support cross-region replication.
//    A replica set can be added in a second region but it shares the same
//    managed domain. Each replica set requires a dedicated subnet (/24 min).
//    The secondary region replica set is added as a separate resource after
//    the primary managed domain is provisioned and healthy (typically 30–45 min).
//
// 3. DOMAIN NAME RESTRICTIONS – Entra DS requires a routable domain suffix
//    (e.g. aadds.contoso.com) or an onmicrosoft.com subdomain. Non-routable
//    suffixes such as .local are not supported.
//
// 4. SUBNET REQUIREMENTS – Entra DS requires a dedicated subnet (/24 minimum)
//    with no other resources. An NSG with specific inbound rules is mandatory:
//    - Allow 443 from AzureActiveDirectoryDomainServices service tag
//    - Allow 5986 from CorpNetSaw service tag (for management plane)
//    - Allow all outbound to Internet
//    Failure to apply these NSG rules causes provisioning failure.
//
// 5. DOMAIN JOIN – Entra DS uses the same DNS server IPs as IaaS DCs (auto-
//    assigned by the managed domain). VNet DNS settings should point to the
//    managed domain's DNS IPs (available as outputs after provisioning).
//
// 6. LICENSING – Entra DS requires Microsoft Entra ID P1 or P2 licenses for
//    all users who authenticate against the managed domain.
//
// 7. BACKUP – No Azure Backup needed; Microsoft manages all backups and HA.
//    ASR is not applicable for Entra DS.
//
// 8. OUTPUT CONTRACT – This module MUST expose the same outputs as
//    identityVnet.bicep so main.bicep files require no conditional changes:
//      output identityVnetId  string
//      output dcVmIds         array   ← empty array for Entra DS
//      output dcVmNames       array   ← empty array for Entra DS
//      output dc1StaticIp     string  ← first DNS server IP from managed domain
//      output dc2StaticIp     string  ← second DNS server IP from managed domain
//      output routeTableId    string
//
// IMPLEMENTATION NOTES:
//   - Microsoft.AAD/domainServices resource API: 2022-12-01
//   - Replica sets: Microsoft.AAD/domainServices/replicaSets API: 2022-12-01
//   - Provisioning time: 30–60 minutes; module must allow for this
//   - DNS IPs only available after provisioning completes (not at deploy time)
//   - Use a deployment script resource or post-deployment step to retrieve DNS IPs
//   - SKU: Enterprise (supports replica sets) or Standard
// =============================================================================

// This file intentionally contains no deployable resources.
// Implementation is tracked as a future sprint item.
// Branch naming convention: feature/entrads-{variant}
// e.g. feature/entrads-sophos-nva, feature/entrads-vwan-azfw

param location string
param environment string
param customerAbbreviation string
param regionAbbreviation string
param vnetName string
param addressPrefix string
param siteOctet int
param hubVnetId string
param nextHopIp string
param onPremAddressPrefix string
param adminUsername string = ''       // Not used for Entra DS – retained for contract compatibility
@secure()
param adminPassword string = ''       // Not used for Entra DS – retained for contract compatibility
param dcCount int = 0                 // Not applicable – Entra DS is managed
param dcVmSize string = ''            // Not applicable
param customerDomainName string
param tags object

// Placeholder outputs matching the ADDS module output contract
// These will be populated by the actual Entra DS implementation
output identityVnetId  string = 'PLACEHOLDER-entrads-not-yet-implemented'
output dcVmIds         array  = []
output dcVmNames       array  = []
output dc1StaticIp     string = 'PLACEHOLDER-retrieve-after-provisioning'
output dc2StaticIp     string = 'PLACEHOLDER-retrieve-after-provisioning'
output routeTableId    string = 'PLACEHOLDER-entrads-not-yet-implemented'

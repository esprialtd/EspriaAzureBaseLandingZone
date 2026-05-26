# Espria Azure Base Landing Zone

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2F**YOUR-ORG**%2F**YOUR-REPO**%2Fmain%2Fazuredeploy.json)
[![Deploy to Azure Gov](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2F**YOUR-ORG**%2F**YOUR-REPO**%2Fmain%2Fazuredeploy.json)

> Before publishing, replace **`YOUR-ORG`** and **`YOUR-REPO`** in both button URLs above with your GitHub organisation and repository name.  
> Example: `https://raw.githubusercontent.com/EspriaLtd/AzureBaseLandingZone/main/azuredeploy.json`

---

## Overview

Multi-region, single-subscription Azure Core Landing Zone for Espria-managed customers. Deploys a complete, production-ready platform foundation across a primary and secondary Azure region in a single operation.

Aligned with the Microsoft **Cloud Adoption Framework (CAF)** and **Well-Architected Framework (WAF)** across all five pillars.

**What gets deployed:**

| Layer | Primary Region | Secondary Region |
|---|---|---|
| Connectivity | Hub VNet, Sophos XG NVA, NSGs, UDRs, Bastion | Hub VNet, Sophos XG NVA, NSGs, UDRs, Bastion |
| Identity | Identity spoke, 2× DC (Zone 1 + Zone 2) | Identity spoke, 1× DC (Zone 1) |
| Management | Management spoke, MGMT VM | Management spoke, MGMT VM |
| Backup | RSV (DCs + MGMT VM), Backup Vault (NVA disk) | RSV (DC), Backup Vault (NVA disk), ASR vault |
| Monitoring | Log Analytics Workspace, VM Insights, AMA, DCR, Action Group | — (all VMs report to primary LAW) |
| Governance | 9× Policy assignments (allowed locations, allowed SKUs, DINE monitoring, auto-tagging) | — (subscription-scope, covers both regions) |

---

## Deployment Methods

Choose the method that suits your workflow. All three methods deploy the same infrastructure.

---

### Method 1 — Deploy to Azure (One-Click Portal)

Click the blue **Deploy to Azure** button at the top of this page.

The Azure portal opens a guided parameter form directly from your repository. All parameters include descriptions and validation. Dropdowns are pre-populated with allowed values. The admin password field is masked. Click **Review + Create** when done.

**The form will prompt for the following:**

| Parameter | Default | Required | Description |
|---|---|---|---|
| `customerName` | — | ✅ | Customer full name, e.g. `Contoso Ltd` |
| `customerAbbreviation` | — | ✅ | 3–5 character abbreviation, e.g. `CON` — used in all resource names |
| `customerDomainName` | — | ✅ | Active Directory domain name, e.g. `contoso.local` |
| `adminPassword` | — | ✅ | VM admin password — 12+ chars, upper, lower, number, symbol |
| `primaryRegion` | `uksouth` | | Primary Azure region. All 54 public regions available |
| `secondaryRegion` | `auto` | | `auto` selects the Microsoft-documented paired region automatically |
| `deploySecondaryRegion` | `true` | | Set to `false` for a primary-only deployment |
| `environment` | `prod` | | `prod` / `dev` / `uat` — used in all resource names |
| `primaryRegionSiteId` | `101` | | 2nd octet of `10.x.0.0/16` for primary region (101–199) |
| `secondaryRegionSiteId` | `102` | | 2nd octet of `10.x.0.0/16` for secondary region |
| `adminUsername` | `espria-admin` | | VM local administrator username |
| `sophosVmSize` | `Standard_D2s_v5` | | Sophos XG NVA VM size |
| `dcVmSize` | `Standard_D2s_v5` | | Domain Controller VM size |
| `mgmtVmSize` | `Standard_B2ms` | | Management jump VM size |
| `enableVmBackup` | `true` | | Azure VM Backup (Enhanced Policy V2) for DCs and MGMT VM |
| `enableNvaDiskBackup` | `true` | | Azure Disk Backup for Sophos XG NVA OS disks |
| `enableAsrMgmtVm` | `true` | | Azure Site Recovery A2A for the Management VM |
| `alertEmailAddress` | `alerts@espria.com` | | Espria NOC alert email for the Azure Monitor Action Group |
| `lawRetentionDays` | `90` | | Log Analytics Workspace retention (30–730 days) |
| `onPremAddressPrefix` | `10.1.0.0/16` | | On-premises address space used in spoke UDRs |

**Before clicking Deploy:**
- Ensure `azuredeploy.json` is at the root of a public (or authenticated) GitHub repository
- Accept Sophos XG Marketplace terms on the target subscription (see [Prerequisites](#prerequisites))
- Confirm the deploying identity has Owner on the subscription and Management Group Contributor at tenant root

---

### Method 2 — Azure CLI (deploy.sh)

```bash
chmod +x deploy.sh

# Full deployment — primary + auto-paired secondary
./deploy.sh \
  -s 00000000-0000-0000-0000-000000000000 \
  -n "Contoso Ltd" \
  -a CON \
  -d contoso.local

# What-if preview — no changes made
./deploy.sh -s <sub-id> -n "Contoso Ltd" -a CON -d contoso.local --what-if

# Primary region only (no secondary hub, NVA, or DC)
./deploy.sh -s <sub-id> -n "Contoso Ltd" -a CON -d contoso.local --no-secondary

# Override secondary region (disable auto-pairing)
./deploy.sh -s <sub-id> -n "Contoso Ltd" -a CON -d contoso.local -r northeurope

# Deploy management groups only (first-time tenant setup)
./deploy.sh -s <sub-id> -n "Contoso Ltd" -a CON -d contoso.local --mgmt-groups-only
```

The admin password is prompted interactively and never written to disk or passed as a CLI argument. The script validates password complexity before proceeding.

**Full option reference:**

| Flag | Description |
|---|---|
| `-s` | Azure subscription ID (required) |
| `-n` | Customer full name (required) |
| `-a` | Customer abbreviation, max 5 chars (required) |
| `-d` | AD domain name, e.g. `contoso.local` (required) |
| `-p` | Primary region (default: `uksouth`) |
| `-r` | Secondary region (default: `auto`) |
| `-e` | Environment: `prod` / `dev` / `uat` (default: `prod`) |
| `-u` | VM admin username (default: `espria-admin`) |
| `--no-secondary` | Skip secondary region deployment |
| `--what-if` | Preview changes only, no deployment |
| `--mgmt-groups-only` | Deploy management groups only |

---

### Method 3 — Azure DevOps Pipeline

Push to `main` triggers the pipeline defined in `azure-pipelines.yaml`.

**Pipeline stages:**

| Stage | Scope | Trigger | Gate |
|---|---|---|---|
| **Validate** | None | All branches | Bicep lint + what-if preview |
| **ManagementGroups** | Tenant | `main` only | Manual approval required |
| **LandingZone** | Subscription | `main` only | Environment approval gate |
| **Verify** | Subscription | After LZ | Automated smoke tests |

**Setup checklist:**

1. **Variable group** — create `lz-deployment-secrets` in Azure DevOps Library:

   | Variable | Secret | Value |
   |---|---|---|
   | `AZURE_SUBSCRIPTION_ID` | No | Target subscription ID |
   | `ADMIN_PASSWORD` | **Yes** | VM admin password |
   | `CUSTOMER_NAME` | No | e.g. `Contoso Ltd` |
   | `CUSTOMER_ABBR` | No | e.g. `CON` |
   | `CUSTOMER_DOMAIN` | No | e.g. `contoso.local` |

2. **Service connections** — two connections required:
   - `sc-espria-lz-tenant` — Management Group Contributor at tenant root (for MG hierarchy)
   - `sc-espria-lz-subscription` — Owner on target subscription

3. **Pipeline environments** — create with approval gates:
   - `lz-management-groups` — protects the ManagementGroups stage
   - `lz-production` — protects the LandingZone stage

---

## Region Selection and Auto-Pairing

Setting `secondaryRegion` to `auto` (the default) automatically selects the Microsoft-documented paired region for the primary. The pairing is defined in `regionPairMap` inside `main.bicep` and `azuredeploy.json`, sourced from the [Azure cross-region replication documentation](https://learn.microsoft.com/azure/reliability/cross-region-replication-azure).

**Common region pairs:**

| Primary | Auto Secondary | Primary | Auto Secondary |
|---|---|---|---|
| UK South | UK West | UK West | UK South |
| North Europe | West Europe | West Europe | North Europe |
| East US | West US | East US 2 | Central US |
| France Central | France South | Germany West Central | Germany North |
| Japan East | Japan West | Korea Central | Korea South |
| Australia East | Australia Southeast | Canada Central | Canada East |
| Sweden Central | Sweden South | Switzerland North | Switzerland West |
| UAE North | UAE Central | Norway East | Norway West |

All 54 Azure public regions are supported. Set `secondaryRegion` to an explicit region name to override the auto-pairing.

---

## Architecture

```
Tenant Root Group
└── {CUST} Landing Zone
    ├── {CUST} Platform
    │   ├── {CUST} Platform - Connectivity
    │   ├── {CUST} Platform - Identity
    │   └── {CUST} Platform - Management
    ├── {CUST} Landing Zones
    │   ├── {CUST} Corp
    │   └── {CUST} Online
    ├── {CUST} Sandbox
    └── {CUST} Decommissioned

Primary Region  e.g. UK South — 10.101.0.0/16
──────────────────────────────────────────────
rg-prod-core-connectivity-CUST-uksouth-01
  vnet-prod-core-connectivity-CUST-uksouth-01   Hub — 10.101.0.0/21
    NVALAN            10.101.0.0/27    Sophos XG LAN NIC (static .0.4, UDR next-hop)
    NVAWAN            10.101.0.64/27   Sophos XG WAN NIC (static .0.68, public IP)
    GatewaySubnet     10.101.0.128/27  Reserved — no gateway deployed
    RouteServerSubnet 10.101.0.160/27  Reserved
    AzureBastionSubnet 10.101.1.0/26  Bastion subnet (Bastion resource lives in mgmt RG)
    PrivateEndpoint   10.101.7.0/24
  CUSTAZUKSSFOS01     Sophos XG NVA
  buv-prod-connectivity-CUST-uksouth-01   Backup Vault — NVA disk backup
  stasr...            ASR cache storage account

rg-prod-core-identity-CUST-uksouth-01
  vnet-prod-core-identity-CUST-uksouth-01   Spoke — 10.101.8.0/22
    DomainControllers  10.101.8.0/24
    PrivateEndpoint    10.101.11.0/24
  CUST-AZUKS-DC01   DC (Zone 1, static 10.101.8.11)
  CUST-AZUKS-DC02   DC (Zone 2, static 10.101.8.12)
  rsv-prod-identity-CUST-uksouth-01   RSV — DC VM backup (Enhanced Policy V2)

rg-prod-core-management-CUST-uksouth-01
  vnet-prod-core-management-CUST-uksouth-01   Spoke — 10.101.248.0/21
    ManagementServers  10.101.248.0/24
    PrivateEndpoint    10.101.255.0/24
  CUST-AZUKS-MGMT01   Management VM (DHCP)
  bastion-prod-core-connectivity-CUST-uksouth-01  (attaches to AzureBastionSubnet cross-RG)
  rsv-prod-management-CUST-uksouth-01   RSV — MGMT VM backup (Enhanced Policy V2)
  log-prod-core-management-CUST-uksouth-01   Log Analytics Workspace
  dcr-prod-vminsights-CUST-uksouth-01   Data Collection Rule
  ag-prod-espria-alerts-CUST-uksouth-01   Action Group

Secondary Region  e.g. UK West — 10.102.0.0/16
────────────────────────────────────────────────
  Mirror of primary with:
    1× DC (Zone 1 only) instead of 2× DC
    ASR Recovery Services Vault for MGMT VM failover target
    Hub-to-hub VNet peering back to primary hub
```

---

## Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| NVA | Sophos XG (BYOL Marketplace) | Espria preferred firewall platform |
| NVA naming | `{CUST}AZ{REG}SFOS01` e.g. `CONAZUKSSFOS01` | Sophos XG Marketplace rejects hyphens in VM hostname |
| NVA NIC IPs | Static — LAN `.0.4`, WAN `.0.68` | UDR next-hop IP must be stable; DHCP would break routing on VM restart |
| DC NICs | Static — `.8.11`, `.8.12` | DNS stability — workloads need a consistent resolver address |
| All other VM NICs | DHCP | Azure best practice; DHCP leases are stable for VM lifetime |
| VPN Gateway | Not deployed | Sophos XG handles site-to-site VPN. `GatewaySubnet` reserved for future use in same VNet — no separate VNet needed |
| Bastion placement | Deployed in **management RG**, attached to `AzureBastionSubnet` in **connectivity VNet** | Bastion on the hub VNet has peering visibility to all spokes. Cross-RG subnet ID reference used |
| Bastion SKU | Standard | Enables native client tunnelling via `az network bastion rdp/ssh` |
| VNet peering | Bidirectional — spoke→hub and hub→spoke | Azure requires two peering objects per pair; both must show `Connected` for traffic to flow |
| DC backup | Azure VM Backup, RSV, Enhanced Policy V2 | V2 required for Premium SSD; 4-hourly RPO, 7-day instant restore |
| NVA backup | Azure Disk Backup, Backup Vault | Disk backup captures snapshots without OS agent — correct for NVA appliances |
| ASR scope | Management VM only | DCs replicate via AD DS over hub-to-hub peering; NVA recovered from disk backup |
| Monitoring | Single central LAW in primary management RG | All regions, all resources funnel to one workspace for unified querying and cost efficiency |
| Auto-tagging | Modify policy (not Audit) | Modify writes the tag — Audit only reports it. Ensures 100% tag coverage regardless of deployment method |
| Allowed Locations | Deny policy at subscription scope | Prevents accidental deployment to non-approved regions |
| Allowed SKUs | Deny policy — D-series v4/v5/v6 2/4/8 vCPU, B-series, F-series | F-series covers NVA; D-series covers all workload VMs; all variants support ASR A2A |

---

## Prerequisites

Before any deployment method:

```bash
# 1. Install / update Azure CLI Bicep
az bicep install

# 2. Accept Sophos XG Marketplace terms on the target subscription
#    (deploy.sh and the DevOps pipeline do this automatically)
az vm image terms accept \
  --publisher sophos \
  --offer sophos-xg \
  --plan byol \
  --subscription <subscription-id>
```

**Identity requirements:**
- Management Group Contributor at tenant root — needed for the 9-group MG hierarchy
- Owner on the target subscription — needed for resource and policy deployment

**Tooling:**
- Azure CLI ≥ 2.55 (for deploy.sh and manual CLI use)
- Azure DevOps with service connections configured (for pipeline)
- Public GitHub repository (for Deploy-to-Azure button)

---

## Post-Deployment Steps

The Bicep deployment is complete when the pipeline Verify stage passes or the CLI script exits successfully. The following steps are required before the platform is production-ready:

| Step | Activity | Detail |
|---|---|---|
| PD-01 | **AD DS Promotion** | Connect to `CUST-AZUKS-DC01` via Bastion. Run `Install-ADDSForest` for the new forest. Repeat `Install-ADDSDomainController` on DC02 and the secondary DC01. |
| PD-02 | **Sophos XG Configuration** | Access the management UI on the NVA LAN IP (`10.x.0.4`). Apply the base firewall policy, configure the on-premises IPSec VPN peer, enable logging to the central LAW. |
| PD-03 | **Disk Backup RBAC** | Grant the Backup Vault managed identity `Disk Backup Reader` on the NVA disk and `Disk Snapshot Contributor` on the connectivity resource group. Required before disk backup can run. |
| PD-04 | **ASR Initial Sync** | Trigger the initial replication sync for MGMT01 from the Azure portal or via `az recoveryservices`. Monitor replication health in the ASR vault. |
| PD-05 | **Policy Remediation** | Run remediation tasks for the three DINE policies (AMA, diagnostics, auto-tagging) against any resources deployed before policy was active. |
| PD-06 | **DNS Verification** | Confirm the identity VNet DNS settings resolve the AD domain. The `dhcpOptions` is pre-configured to point to DC static IPs. |
| PD-07 | **Site-to-Site VPN** | Configure the Sophos XG IPSec tunnel to the on-premises peer. UDRs are pre-configured to route on-premises traffic via the NVA. |
| PD-08 | **Defender for Cloud** | Enable at subscription level. Assign the Microsoft Cloud Security Benchmark (MCSB) initiative. Feeds into the central LAW automatically. |
| PD-09 | **NinjaOne Agent** | Deploy via VM extension or GPO following DC promotion. |
| PD-10 | **Tenable** | Connect the subscription to Tenable.io or deploy a Nessus scanner VM in the management spoke. |

---

## Backup and Recovery Reference

| Resource | Method | Vault | Policy | RG |
|---|---|---|---|---|
| DC VMs (primary) | Azure VM Backup | RSV `rsv-prod-identity-CUST-{region}-01` | Enhanced V2 — 4-hourly, 30-day daily | Identity RG |
| DC VM (secondary) | Azure VM Backup | RSV `rsv-prod-identity-CUST-{region}-01` | Enhanced V2 — 4-hourly, 30-day daily | Identity RG |
| MGMT VM (primary) | Azure VM Backup | RSV `rsv-prod-management-CUST-{region}-01` | Enhanced V2 — 4-hourly, 30-day daily | Management RG |
| MGMT VM ASR | Azure Site Recovery A2A | RSV `rsv-prod-core-management-asr-CUST-{sec-region}-01` | RPO ≤1hr, app-consistent 4hr | Secondary Mgmt RG |
| Sophos XG OS disk (primary) | Azure Disk Backup | BUV `buv-prod-connectivity-CUST-{region}-01` | 4-hourly, 7-day snapshot + 30-day vault | Connectivity RG |
| Sophos XG OS disk (secondary) | Azure Disk Backup | BUV `buv-prod-connectivity-CUST-{region}-01` | 4-hourly, 7-day snapshot + 30-day vault | Connectivity RG |

Enhanced Policy V2 (RSV) includes: 7-day instant restore, 30-day daily, 12-week weekly, 12-month monthly, 1-year yearly, Zone-Redundant vault storage, soft delete 14 days.

---

## Governance Policies

All 9 policy assignments are deployed at **subscription scope**:

| # | Assignment Name | Effect | Built-in ID | Purpose |
|---|---|---|---|---|
| 1 | Allowed Locations | Deny | `e56962a6` | Restricts deployment to primary + secondary regions only |
| 2 | Allowed VM SKUs | Deny | `cccc23c7` | D-series v4/v5/v6 2/4/8 vCPU, B-series, F-series (NVA) |
| 3 | Deploy AMA — Windows VMs | DINE | `ca817e41` | Auto-deploys Azure Monitor Agent + DCR association |
| 4 | VM Diagnostic Settings → LAW | DINE | `0868462e` | Auto-configures diagnostics to central workspace |
| 5 | Auto-tag: CreatedBy | Modify | `b27a0cbd` | Inherits CreatedBy from resource group if missing |
| 6 | Auto-tag: ManagedBy | Modify | `b27a0cbd` | Inherits ManagedBy from resource group if missing |
| 7 | Auto-tag: Environment | Modify | `b27a0cbd` | Inherits Environment from resource group if missing |
| 8 | Auto-tag: Customer | Modify | `b27a0cbd` | Inherits Customer from resource group if missing |

DINE and Modify assignments are given system-assigned managed identities. DINE assignments receive Contributor; Modify assignments receive Tag Contributor.

---

## Naming Conventions

| Resource | Pattern | Example |
|---|---|---|
| Resource Group | `rg-{env}-{function}-{CUST}-{region}-01` | `rg-prod-core-identity-CON-uksouth-01` |
| Virtual Network | `vnet-{env}-{function}-{CUST}-{region}-01` | `vnet-prod-core-connectivity-CON-uksouth-01` |
| Sophos XG NVA | `{CUST}AZ{REG}SFOS01` | `CONAZUKSSFOS01` |
| Domain Controller | `{CUST}-AZ{REG}-DC0x` | `CON-AZUKS-DC01` |
| Management VM | `{CUST}-AZ{REG}-MGMT01` | `CON-AZUKS-MGMT01` |
| Bastion | `bastion-{env}-core-connectivity-{CUST}-{region}-01` | `bastion-prod-core-connectivity-CON-uksouth-01` |
| Recovery Services Vault | `rsv-{env}-{function}-{CUST}-{region}-01` | `rsv-prod-identity-CON-uksouth-01` |
| Backup Vault | `buv-{env}-{function}-{CUST}-{region}-01` | `buv-prod-connectivity-CON-uksouth-01` |
| Log Analytics Workspace | `log-{env}-core-management-{CUST}-{region}-01` | `log-prod-core-management-CON-uksouth-01` |
| Data Collection Rule | `dcr-{env}-vminsights-{CUST}-{region}-01` | `dcr-prod-vminsights-CON-uksouth-01` |
| Action Group | `ag-{env}-espria-alerts-{CUST}-{region}-01` | `ag-prod-espria-alerts-CON-uksouth-01` |
| NSG | `nsg-{Subnet}-{VNetName}` | `nsg-DomainControllers-vnet-prod-...` |
| Route Table | `rt-{env}-{function}-{CUST}-{region}-01` | `rt-prod-core-identity-CON-uksouth-01` |
| Policy Assignment | `pa-{function}-{env}-{CUST}` | `pa-allowed-locations-prod-CON` |
| ASR Cache Storage | `stasr{env}{cust}{regionabrv}01` | `stasrprodconuks01` |

---

## Repository Structure

```
EspriaBaseLandingZone/
├── main.bicep                        Root orchestration — 23 modules, subscription scope
├── azuredeploy.json                  ARM template for the Deploy-to-Azure portal button
├── azuredeploy.parameters.json       Companion parameters used by the portal form
├── main.parameters.json              Parameter file for CLI and DevOps deployments
├── azure-pipelines.yaml              Azure DevOps 4-stage pipeline
├── deploy.sh                         One-click CLI deployment script
├── README.md
└── modules/
    ├── governance/
    │   ├── managementGroups.bicep    CAF MG hierarchy — tenant scope
    │   ├── resourceGroups.bicep      Core RG creation — subscription scope
    │   └── policies.bicep            9× policy assignments — subscription scope
    ├── connectivity/
    │   ├── hubConnectivity.bicep     Hub VNet + Sophos XG NVA + Bastion subnet
    │   ├── hubToHubPeering.bicep     Cross-region hub-to-hub peering
    │   ├── spokeToHubPeering.bicep   Hub → spoke return peering
    │   └── vnetPeering.bicep         Generic peering helper
    ├── identity/
    │   └── identityVnet.bicep        Identity spoke VNet + IaaS DC VMs
    ├── management/
    │   └── managementVnet.bicep      Management spoke VNet + MGMT VM + Bastion
    ├── backup/
    │   ├── backupAndRecovery.bicep   RSV (VM Backup) + Backup Vault (Disk Backup)
    │   ├── asrReplication.bicep      ASR A2A replication chain — secondary scope
    │   └── asrCacheStorage.bicep     ASR staging storage — primary connectivity RG
    └── monitoring/
        └── centralMonitoring.bicep   LAW + VM Insights + AMA + DCR + Action Group
```

---

## Contributing and Customer Customisation

This repository is the Espria master template. For each customer deployment:

1. Copy `main.parameters.json` and rename it `{customer}-parameters.json`
2. Populate the customer-specific values (name, abbreviation, domain, regions, site IDs)
3. Store the admin password in Azure Key Vault and reference it via the `keyVault` reference block in the parameters file — never store passwords in the repository
4. Raise a branch per customer engagement and tag each deployment with the customer abbreviation and date

---

*Maintained by Espria Solutions Architecture. For questions contact your Solutions Architect or open an issue in this repository.*

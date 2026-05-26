# Espria Azure Base Landing Zone

Six-variant, multi-region Azure Landing Zone for Espria-managed customers. Three connectivity models × two identity types, sharing a common platform foundation. All `azuredeploy.json` files are pre-built and ready to use — no compilation required.

---

## Variants at a Glance

| | Sophos NVA | vWAN + AZFW | AZFW + VPN GW |
|---|---|---|---|
| **AD DS** | `sophos-nva` | `vwan-azfw` | `hub-azfw-vpngw` |
| **Entra DS** | `sophos-nva-entrads` | `vwan-azfw-entrads` | `hub-azfw-vpngw-entrads` |

| Variant | Hub Type | Firewall | VPN | Identity |
|---|---|---|---|---|
| sophos-nva | VNet hub-spoke | Sophos XG NVA (BYOL) | Sophos XG | IaaS AD DS (DCs) |
| vwan-azfw | Azure Virtual WAN | Azure Firewall Premium (secured hub) | Optional vWAN VPN GW | IaaS AD DS (DCs) |
| hub-azfw-vpngw | VNet hub-spoke | Azure Firewall Premium (standalone) | Optional active-active VPN GW | IaaS AD DS (DCs) |
| sophos-nva-entrads | VNet hub-spoke | Sophos XG NVA (BYOL) | Sophos XG | Entra Domain Services |
| vwan-azfw-entrads | Azure Virtual WAN | Azure Firewall Premium (secured hub) | Optional vWAN VPN GW | Entra Domain Services |
| hub-azfw-vpngw-entrads | VNet hub-spoke | Azure Firewall Premium (standalone) | Optional active-active VPN GW | Entra Domain Services |

---

## Deploy to Azure (One-Click)

> Replace `**YOUR-ORG**` and `**YOUR-REPO**` before publishing. The `azuredeploy.json` files are pre-built in each variant folder — no `az bicep build` step required.

### AD DS Variants

| Variant | Button |
|---|---|
| Sophos NVA + AD DS | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fesrpiraltd%2FEspriaAzureBaseLandingZone%2Fmain%2Fvariants%2Fsophos-nva%2Fazuredeploy.json) |
| vWAN + Azure Firewall + AD DS | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fesrpiraltd%2FEspriaAzureBaseLandingZone%2Fmain%2Fvariants%2Fvwan-azfw%2Fazuredeploy.json) |
| Azure Firewall + VPN GW + AD DS | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fesrpiraltd%2FEspriaAzureBaseLandingZone%2Fmain%2Fvariants%2Fhub-azfw-vpngw%2Fazuredeploy.json) |

### Entra DS Variants

| Variant | Button |
|---|---|
| Sophos NVA + Entra DS | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fesrpiraltd%2FEspriaAzureBaseLandingZone%2Fmain%2Fvariants%2Fsophos-nva-entrads%2Fazuredeploy.json) |
| vWAN + Azure Firewall + Entra DS | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fesrpiraltd%2FEspriaAzureBaseLandingZone%2Fmain%2Fvariants%2Fvwan-azfw-entrads%2Fazuredeploy.json) |
| Azure Firewall + VPN GW + Entra DS | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fesrpiraltd%2FEspriaAzureBaseLandingZone%2Fmain%2Fvariants%2Fhub-azfw-vpngw-entrads%2Fazuredeploy.json) |

### About the azuredeploy.json files

The `azuredeploy.json` in each variant folder is a pre-built ARM template. It renders the portal parameter form for the Deploy-to-Azure button and passes all parameters through to the Bicep deployment. **You do not need to run `az bicep build` to use these files.** They are maintained in the repository alongside the Bicep source. If you modify a variant's `main.bicep`, regenerate its `azuredeploy.json` by running:

```bash
az bicep build --file variants/<variant>/main.bicep --outfile variants/<variant>/azuredeploy.json
```

---

## Deploy via CLI

```bash
chmod +x deploy.sh

# AD DS variants
./deploy.sh -v sophos-nva         -s <sub-id> -n "Contoso Ltd" -a CON -d contoso.local
./deploy.sh -v vwan-azfw          -s <sub-id> -n "Contoso Ltd" -a CON -d contoso.local
./deploy.sh -v hub-azfw-vpngw     -s <sub-id> -n "Contoso Ltd" -a CON -d contoso.local

# Entra DS variants (domain MUST be routable, e.g. aadds.contoso.com)
./deploy.sh -v sophos-nva-entrads         -s <sub-id> -n "Contoso Ltd" -a CON -d aadds.contoso.com
./deploy.sh -v vwan-azfw-entrads          -s <sub-id> -n "Contoso Ltd" -a CON -d aadds.contoso.com
./deploy.sh -v hub-azfw-vpngw-entrads     -s <sub-id> -n "Contoso Ltd" -a CON -d aadds.contoso.com

# Options (all variants)
--what-if           Preview changes only
--no-secondary      Primary region only
--mgmt-groups-only  Deploy CAF management group hierarchy only

# Optional VPN Gateway (vwan-azfw and hub-azfw-vpngw variants)
./deploy.sh -v hub-azfw-vpngw -s <sub-id> -n "Contoso Ltd" -a CON -d contoso.local \
  -- deployVpnGateway=true
```

---

## Deploy via Azure DevOps

Pipeline `azure-pipelines.yaml` supports all six variants. Select at queue time:

1. Run Pipeline → set **Landing Zone Variant** to one of the six values
2. Set **Primary Azure Region** and **Deploy Secondary Region**

**One-time setup:**

| Item | Detail |
|---|---|
| Variable group | `lz-deployment-secrets` with `AZURE_SUBSCRIPTION_ID`, `ADMIN_PASSWORD` (secret), `CUSTOMER_NAME`, `CUSTOMER_ABBR`, `CUSTOMER_DOMAIN` |
| Service connection (subscription) | `sc-espria-lz-subscription` — Owner on target subscription |
| Service connection (tenant) | `sc-espria-lz-tenant` — Management Group Contributor at tenant root |
| Environment (approval gate) | `lz-management-groups` |
| Environment (approval gate) | `lz-production` |

---

## Repository Structure

```
EspriaBaseLandingZone/
│
├── shared/                                    Modules shared by ALL variants
│   ├── governance/
│   │   ├── managementGroups.bicep             CAF MG hierarchy (tenant scope)
│   │   ├── resourceGroups.bicep               Core RG creation (subscription scope)
│   │   └── policies.bicep                     9× policy assignments
│   ├── identity/
│   │   ├── adds/
│   │   │   └── identityVnet.bicep             IaaS AD DS: DomainControllers subnet + DC VMs
│   │   └── entrads/
│   │       └── entraDomainServices.bicep      Entra DS: EntraDomainServices subnet + managed domain
│   ├── management/
│   │   └── managementVnet.bicep               Management spoke + VM + Bastion
│   ├── backup/
│   │   ├── backupAndRecovery.bicep            RSV (VM Backup) + Backup Vault (Disk)
│   │   ├── asrReplication.bicep               ASR A2A – Management VM
│   │   └── asrCacheStorage.bicep              ASR staging storage
│   └── monitoring/
│       └── centralMonitoring.bicep            LAW + VM Insights + AMA + Action Group
│
├── variants/
│   ├── sophos-nva/                            AD DS + Sophos NVA
│   │   ├── main.bicep
│   │   ├── main.parameters.json
│   │   ├── azuredeploy.json                   ← pre-built, ready to use
│   │   └── connectivity/
│   │       ├── hubConnectivity.bicep          Hub VNet + Sophos XG NVA
│   │       ├── hubToHubPeering.bicep
│   │       ├── spokeToHubPeering.bicep
│   │       └── vnetPeering.bicep
│   │
│   ├── vwan-azfw/                             AD DS + vWAN + Azure Firewall
│   │   ├── main.bicep
│   │   ├── main.parameters.json
│   │   ├── azuredeploy.json                   ← pre-built, ready to use
│   │   └── connectivity/
│   │       ├── virtualWan.bicep               Global vWAN (Standard SKU)
│   │       ├── vwanHub.bicep                  vWAN Hub + Azure Firewall + Routing Intent
│   │       └── vwanSpokeVnet.bicep            Spoke VNets (no UDR, vWAN manages routing)
│   │
│   ├── hub-azfw-vpngw/                        AD DS + Azure Firewall + VPN GW (optional)
│   │   ├── main.bicep
│   │   ├── main.parameters.json
│   │   ├── azuredeploy.json                   ← pre-built, ready to use
│   │   └── connectivity/
│   │       ├── hubConnectivityAzfw.bicep      Hub VNet + Azure Firewall + optional VPN GW
│   │       ├── hubToHubPeering.bicep
│   │       ├── spokeToHubPeering.bicep
│   │       └── vnetPeering.bicep
│   │
│   ├── sophos-nva-entrads/                    Entra DS + Sophos NVA
│   │   ├── main.bicep
│   │   ├── main.parameters.json
│   │   └── azuredeploy.json                   ← pre-built, ready to use
│   │   └── connectivity/  (same as sophos-nva)
│   │
│   ├── vwan-azfw-entrads/                     Entra DS + vWAN + Azure Firewall
│   │   ├── main.bicep
│   │   ├── main.parameters.json
│   │   └── azuredeploy.json                   ← pre-built, ready to use
│   │   └── connectivity/  (same as vwan-azfw)
│   │
│   └── hub-azfw-vpngw-entrads/                Entra DS + Azure Firewall + VPN GW (optional)
│       ├── main.bicep
│       ├── main.parameters.json
│       ├── azuredeploy.json                   ← pre-built, ready to use
│       └── connectivity/  (same as hub-azfw-vpngw)
│
├── .azure/
│   └── preparation-manifest.md               Deployment manifest (azure-prepare)
├── azure-pipelines.yaml                       Multi-variant DevOps pipeline
├── deploy.sh                                  Multi-variant CLI script
└── README.md
```

---

## Architecture – Connectivity Models

### A: Hub-Spoke with Sophos XG NVA (sophos-nva, sophos-nva-entrads)

```
Primary Region  10.101.0.0/16
  rg-prod-core-connectivity-CUST-uksouth-01
    vnet-prod-core-connectivity-CUST-uksouth-01  [Hub 10.101.0.0/21]
      NVALAN            10.101.0.0/27    Sophos XG LAN (static .0.4, UDR next-hop)
      NVAWAN            10.101.0.64/27   Sophos XG WAN (static .0.68, public IP)
      GatewaySubnet     10.101.0.128/27  Reserved (no GW deployed)
      RouteServerSubnet 10.101.0.160/27  Reserved
      AzureBastionSubnet 10.101.1.0/26  Bastion attaches here (from mgmt RG)
      PrivateEndpoint   10.101.7.0/24
    CUSTAZUKSSFOS01   Sophos XG NVA (BYOL)
    buv-…             Backup Vault (NVA disk backup)

  rg-prod-core-identity-CUST-uksouth-01
    vnet-prod-core-identity-CUST-uksouth-01  [Spoke 10.101.8.0/22]
      DomainControllers  10.101.8.0/24   ← AD DS variant
      EntraDomainServices 10.101.8.0/24  ← Entra DS variant (same range, different subnet name)
      PrivateEndpoint    10.101.11.0/24
    DC01 (Zone 1, static .8.11) + DC02 (Zone 2, static .8.12)   ← AD DS only
    Entra DS managed domain (aadds.contoso.com)                  ← Entra DS only
    rsv-…  Recovery Services Vault (VM backup, AD DS only)

  rg-prod-core-management-CUST-uksouth-01
    vnet-prod-core-management-CUST-uksouth-01  [Spoke 10.101.248.0/21]
    MGMT VM (DHCP) + Bastion + LAW + DCR + Action Group + RSV
```

### B: Azure Virtual WAN + Azure Firewall (vwan-azfw, vwan-azfw-entrads)

```
Primary Region  10.101.0.0/16
  No connectivity VNet — vWAN Hub replaces it

  rg-prod-core-connectivity-CUST-uksouth-01
    hub-vwan-prod-core-connectivity-CUST-uksouth-01  [vWAN Hub 10.101.0.0/23]
      Azure Firewall Premium  (hub-injected, AZFW_Hub SKU, no AzureFirewallSubnet needed)
      vWAN VPN Gateway        (optional, Microsoft.Network/vpnGateways, scale-unit model)
    vwan-prod-core-connectivity-CUST-01  (Global vWAN resource, metadata in primary region)

  rg-prod-core-identity-CUST-uksouth-01
    vnet-prod-core-identity-CUST-uksouth-01  [Spoke 10.101.8.0/22]
      DomainControllers   10.101.8.0/24    ← AD DS variant  (nsg-DomainControllers-…, UDR → AZFW)
      EntraDomainServices 10.101.8.0/24    ← Entra DS variant (mandatory NSG, UDR → AZFW)
      PrivateEndpoint     10.101.11.0/24   (nsg-PrivateEndpoint-…, UDR → AZFW)
    ← Connected to hub via hubVirtualNetworkConnections (not VNet peering)
    ← No UDRs on subnets: vWAN routing intent injects 0.0.0.0/0 → Azure Firewall automatically
    DC01 (static .8.11) + DC02 (static .8.12)        ← AD DS only
    Entra DS managed domain (aadds.contoso.com)       ← Entra DS only (30–60 min provisioning)
    rsv-…  Recovery Services Vault (DC VM backup)     ← AD DS only

  rg-prod-core-management-CUST-uksouth-01
    vnet-prod-core-management-CUST-uksouth-01  [Spoke 10.101.248.0/21]
      ManagementServers   10.101.248.0/24  (nsg-ManagementServers-…, UDR → AZFW)
      AzureBastionSubnet  10.101.249.0/26  ← Bastion lives HERE (no hub VNet in vWAN variant)
      PrivateEndpoint     10.101.255.0/24  (nsg-PrivateEndpoint-…, UDR → AZFW)
    ← Connected to hub via hubVirtualNetworkConnections
    MGMT VM + Bastion + LAW + DCR + Action Group + RSV (MGMT VM backup)
```

### C: Hub-Spoke + Azure Firewall + VPN Gateway (hub-azfw-vpngw, hub-azfw-vpngw-entrads)

```
Primary Region  10.101.0.0/16
  rg-prod-core-connectivity-CUST-uksouth-01
    vnet-prod-core-connectivity-CUST-uksouth-01  [Hub 10.101.0.0/21]
      AzureFirewallSubnet  10.101.0.0/26    Azure Firewall (required name, min /26, no NSG)
      GatewaySubnet        10.101.0.128/27  VPN Gateway (reserved; active-active when deployVpnGateway=true)
      RouteServerSubnet    10.101.0.160/27  Reserved
      AzureBastionSubnet   10.101.1.0/26    Bastion attaches here (from mgmt RG cross-RG ref)
      PrivateEndpoint      10.101.7.0/24
    azfw-…  Azure Firewall Premium (static .0.4, AZFW_VNet SKU, zone-redundant)
    vnet-gw-…  Active-Active VPN Gateway (VpnGw1AZ, 2× PIP, BGP)  ← when deployVpnGateway=true

  rg-prod-core-identity-CUST-uksouth-01
    vnet-prod-core-identity-CUST-uksouth-01  [Spoke 10.101.8.0/22]
      DomainControllers   10.101.8.0/24    ← AD DS variant  (nsg-DomainControllers-…, UDR → AZFW .0.4)
      EntraDomainServices 10.101.8.0/24    ← Entra DS variant (mandatory NSG, UDR → AZFW .0.4)
      PrivateEndpoint     10.101.11.0/24   (nsg-PrivateEndpoint-…, UDR → AZFW .0.4)
    ← Peered to hub (spokeToHubPeering + hub-to-identity return peering)
    DC01 (Zone 1, static .8.11) + DC02 (Zone 2, static .8.12)   ← AD DS only
    Entra DS managed domain (aadds.contoso.com)                  ← Entra DS only
    rsv-…  Recovery Services Vault (DC VM backup, AD DS only)

  rg-prod-core-management-CUST-uksouth-01
    vnet-prod-core-management-CUST-uksouth-01  [Spoke 10.101.248.0/21]
      ManagementServers  10.101.248.0/24   (nsg-ManagementServers-…, UDR → AZFW .0.4)
      PrivateEndpoint    10.101.255.0/24   (nsg-PrivateEndpoint-…, UDR → AZFW .0.4)
    ← Peered to hub (spokeToHubPeering + hub-to-management return peering)
    ← Bastion attaches to AzureBastionSubnet in the hub VNet (cross-RG reference)
    MGMT VM + Bastion (hub subnet) + LAW + DCR + Action Group + RSV (MGMT VM backup)
```

---

## Address Space — All Variants

| Range | Purpose (all variants) |
|---|---|
| `10.x.0.0/21` | Connectivity hub VNet (Variants A and C) |
| `10.x.0.0/23` | vWAN Hub (Variant B — same block, no VNet) |
| `10.x.8.0/22` | Identity spoke VNet |
| `10.x.248.0/21` | Management spoke VNet |

Where `x` = site ID (default 101 primary, 102 secondary). The `/16` per site is fully consistent across all variants.

---

## Variant Selection Guide

| Need | Recommended |
|---|---|
| Existing Sophos licences / preference for NVA | sophos-nva or sophos-nva-entrads |
| Large customer, many workload spokes, future global expansion | vwan-azfw or vwan-azfw-entrads |
| Azure-native firewalling + proven site-to-site VPN to on-premises | hub-azfw-vpngw or hub-azfw-vpngw-entrads |
| IaaS DCs needed (GPO, LDAP, legacy app support) | Any AD DS variant |
| No DC VMs, PaaS-first, M365 E3/E5 already licensed | Any Entra DS variant |
| Mixed environment (Azure + on-prem AD) needing full forest trust | AD DS variants |
| Pure cloud, no on-prem dependency | Entra DS variants |

---

## AD DS vs Entra Domain Services

| Aspect | AD DS (adds) | Entra Domain Services (entrads) |
|---|---|---|
| Infrastructure | IaaS VMs (DC01, DC02) | PaaS managed domain |
| Subnet name | `DomainControllers` | `EntraDomainServices` |
| Domain suffix | Any (.local supported) | Routable only (e.g. aadds.contoso.com) |
| Licensing | Included in Azure consumption | Entra ID P1/P2 required |
| Provisioning time | Immediate | 30–60 minutes |
| VM Backup | Required (Enhanced Policy V2) | Not applicable (Microsoft-managed) |
| ASR replication | DC not replicated (AD replication handles DR) | Not applicable |
| DNS IPs | Static (.8.11, .8.12) known at deploy time | Auto-assigned post-provisioning |
| Replica sets (secondary) | 1× DC in secondary region | Enterprise SKU, replica set deployed after primary is healthy |
| GPO / LDAP / Kerberos | Full AD DS feature set | Limited subset (no Schema extensions, no Forest Trust) |

---

## Optional Parameters

### VPN Gateway (hub-azfw-vpngw and hub-azfw-vpngw-entrads)

| Parameter | Default | Description |
|---|---|---|
| `deployVpnGateway` | `false` | Deploy active-active VPN Gateway (VpnGw1AZ). GatewaySubnet always reserved. |
| `vpnGwSku` | `VpnGw1AZ` | VPN GW SKU. AZ suffix = zone-redundant. |
| `bgpAsn` | `65000` | Azure-side BGP ASN. Must not match on-premises ASN. |

### vWAN VPN Gateway (vwan-azfw and vwan-azfw-entrads)

| Parameter | Default | Description |
|---|---|---|
| `deployVpnGateway` | `false` | Deploy vWAN VPN Gateway (Microsoft.Network/vpnGateways). Adds ~30 min. |
| `vpnGwScaleUnit` | `1` | Scale unit: 1 = 500 Mbps aggregate (active-active pair). |

### vWAN Hub Address (vwan-azfw and vwan-azfw-entrads)

| Parameter | Default | Description |
|---|---|---|
| `primaryHubPrefix` | _(empty)_ | Auto-derives `10.{siteId}.0.0/23`. Override only if needed. |
| `secondaryHubPrefix` | _(empty)_ | Auto-derives `10.{siteId}.0.0/23` for secondary site ID. |

---

## Governance Policies (all variants)

9 assignments at subscription scope:

| # | Name | Effect | Purpose |
|---|---|---|---|
| 1 | Allowed Locations | Deny | Restrict to primary + secondary regions + global |
| 2 | Allowed VM SKUs | Deny | D-series v4/v5/v6 2/4/8 vCPU, B-series, F-series (NVA) |
| 3 | Deploy AMA – Windows VMs | DINE | Auto-enrol future VMs into Azure Monitor Agent |
| 4 | VM Diagnostics → LAW | DINE | Auto-configure diagnostics to central workspace |
| 5 | Auto-tag: CreatedBy | Modify | Inherit from resource group if missing |
| 6 | Auto-tag: ManagedBy | Modify | Inherit from resource group if missing |
| 7 | Auto-tag: Environment | Modify | Inherit from resource group if missing |
| 8 | Auto-tag: Customer | Modify | Inherit from resource group if missing |

---

## Prerequisites

```bash
# Azure CLI with Bicep
az bicep install

# Sophos NVA variants only
az vm image terms accept --publisher sophos --offer sophos-xg --plan byol \
  --subscription <subscription-id>

# Entra DS variants — additional requirements:
# 1. Domain must be verified in Entra ID (portal.azure.com → Entra ID → Custom domains)
# 2. Entra ID P1 or P2 licences assigned to all authenticating users
# 3. Domain name must be routable (e.g. aadds.contoso.com) — .local not supported
```

---

## Post-Deployment Steps

| Step | AD DS variants | Entra DS variants |
|---|---|---|
| PD-01 | DC promotion via Bastion (Install-ADDSForest) | Entra DS provisions automatically (~45 min). Set VNet DNS to managed domain IPs post-provisioning. |
| PD-02 | Firewall policy / VPN config | Firewall policy / VPN config |
| PD-03 | Disk Backup RBAC for NVA (Sophos variants) | Disk Backup RBAC for NVA (Sophos variants) |
| PD-04 | ASR initial sync (MGMT VM) | ASR initial sync (MGMT VM) |
| PD-05 | Policy remediation tasks | Policy remediation tasks |
| PD-06 | DNS verification | Update VNet DNS to Entra DS DNS IPs (from managed domain properties) |
| PD-07 | Site-to-site VPN config | Site-to-site VPN config |
| PD-08 | Defender for Cloud + MCSB | Defender for Cloud + MCSB |
| PD-09 | NinjaOne agent | NinjaOne agent |
| PD-10 | Tenable | Tenable |

---

## Naming Conventions

| Resource | Pattern | Example |
|---|---|---|
| Resource Group | `rg-{env}-{function}-{CUST}-{region}-01` | `rg-prod-core-identity-CON-uksouth-01` |
| Hub VNet | `vnet-{env}-core-connectivity-{CUST}-{region}-01` | — |
| vWAN | `vwan-{env}-core-connectivity-{CUST}-01` | `vwan-prod-core-connectivity-CON-01` |
| vWAN Hub | `hub-vwan-{env}-core-connectivity-{CUST}-{region}-01` | — |
| Sophos XG | `{CUST}AZ{REG}SFOS01` | `CONAZUKSSFOS01` |
| Azure Firewall | `azfw-{env}-core-connectivity-{CUST}-{region}-01` | — |
| VPN Gateway | `vnet-gw-{env}-core-connectivity-{CUST}-{region}-01` | — |
| Firewall Policy | `fwpol-{env}-core-{CUST}-{region}-01` | — |
| DC VMs | `{CUST}-AZ{REG}-DC0x` | `CON-AZUKS-DC01` |
| MGMT VM | `{CUST}-AZ{REG}-MGMT01` | `CON-AZUKS-MGMT01` |
| RSV | `rsv-{env}-{function}-{CUST}-{region}-01` | — |
| Backup Vault | `buv-{env}-{function}-{CUST}-{region}-01` | — |
| LAW | `log-{env}-core-management-{CUST}-{region}-01` | — |
| DCR | `dcr-{env}-vminsights-{CUST}-{region}-01` | — |
| Action Group | `ag-{env}-espria-alerts-{CUST}-{region}-01` | — |
| Policy Assignment | `pa-{function}-{env}-{CUST}` | `pa-allowed-locations-prod-CON` |

---

*Maintained by Espria Solutions Architecture. Contact your Solutions Architect or raise an issue in this repository.*

# Espria Azure Landing Zone

Multi-variant, multi-region Azure Landing Zone for Espria-managed customers. Three connectivity variants in a single repository, sharing a common platform foundation.

---

## Variants

| Variant | Connectivity | Firewall | VPN | Folder |
|---|---|---|---|---|
| **A: sophos-nva** | Hub-Spoke VNet | Sophos XG NVA (BYOL) | Sophos XG handles VPN | `variants/sophos-nva/` |
| **B: vwan-azfw** | Azure Virtual WAN (Standard) | Azure Firewall Premium (secured hub) | vWAN VPN Gateway (add-on) | `variants/vwan-azfw/` |
| **C: hub-azfw-vpngw** | Hub-Spoke VNet | Azure Firewall Premium (standalone) | Active-Active VPN Gateway (VpnGw1AZ) | `variants/hub-azfw-vpngw/` |

All variants share the same identity (IaaS AD DS), management, backup, monitoring, and governance modules.

---

## Repository Structure

```
EspriaBaseLandingZone/
├── shared/                               Modules used by all variants
│   ├── governance/
│   │   ├── managementGroups.bicep        CAF MG hierarchy (tenant scope)
│   │   ├── resourceGroups.bicep          Core RG creation (subscription scope)
│   │   └── policies.bicep                9× policy assignments (sub scope)
│   ├── identity/
│   │   ├── adds/
│   │   │   └── identityVnet.bicep        IaaS AD DS Domain Controllers
│   │   └── entrads/
│   │       └── entraDomainServices.bicep Future: Entra Domain Services
│   ├── management/
│   │   └── managementVnet.bicep          Management spoke + VM + Bastion
│   ├── backup/
│   │   ├── backupAndRecovery.bicep       RSV (VM Backup) + Backup Vault
│   │   ├── asrReplication.bicep          ASR A2A for MGMT VM
│   │   └── asrCacheStorage.bicep         ASR staging storage
│   └── monitoring/
│       └── centralMonitoring.bicep       LAW + VM Insights + AMA + Action Group
│
├── variants/
│   ├── sophos-nva/                       Variant A
│   │   ├── main.bicep
│   │   ├── main.parameters.json
│   │   └── connectivity/
│   │       ├── hubConnectivity.bicep     Hub VNet + Sophos XG NVA
│   │       ├── hubToHubPeering.bicep     Cross-region hub peering
│   │       ├── spokeToHubPeering.bicep   Hub → spoke return peering
│   │       └── vnetPeering.bicep
│   │
│   ├── vwan-azfw/                        Variant B
│   │   ├── main.bicep
│   │   ├── main.parameters.json
│   │   └── connectivity/
│   │       ├── virtualWan.bicep          Global vWAN resource
│   │       ├── vwanHub.bicep             vWAN Hub + Azure Firewall + Routing Intent
│   │       └── vwanSpokeVnet.bicep       Spoke VNets (no UDR, no peering)
│   │
│   └── hub-azfw-vpngw/                   Variant C
│       ├── main.bicep
│       ├── main.parameters.json
│       └── connectivity/
│           ├── hubConnectivityAzfw.bicep  Hub VNet + Azure Firewall + AA VPN GW
│           ├── hubToHubPeering.bicep
│           ├── spokeToHubPeering.bicep
│           └── vnetPeering.bicep
│
├── azure-pipelines.yaml                  Multi-variant DevOps pipeline
├── deploy.sh                             Multi-variant CLI script
└── README.md
```

---

## Deploy to Azure (One-Click)

> Replace `**YOUR-ORG**` and `**YOUR-REPO**` with your GitHub org and repo name before publishing.

| Variant | Button |
|---|---|
| Sophos NVA | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2F**YOUR-ORG**%2F**YOUR-REPO**%2Fmain%2Fvariants%2Fsophos-nva%2Fazuredeploy.json) |
| vWAN + Azure Firewall | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2F**YOUR-ORG**%2F**YOUR-REPO**%2Fmain%2Fvariants%2Fvwan-azfw%2Fazuredeploy.json) |
| Azure Firewall + VPN GW | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2F**YOUR-ORG**%2F**YOUR-REPO**%2Fmain%2Fvariants%2Fhub-azfw-vpngw%2Fazuredeploy.json) |

Each variant requires its own `azuredeploy.json` (ARM template) generated from the variant's `main.bicep` via `az bicep build`.

---

## Deploy via CLI

```bash
chmod +x deploy.sh

# Variant A – Sophos NVA
./deploy.sh -v sophos-nva -s <sub-id> -n "Contoso Ltd" -a CON -d contoso.local

# Variant B – vWAN + Azure Firewall
./deploy.sh -v vwan-azfw -s <sub-id> -n "Contoso Ltd" -a CON -d contoso.local

# Variant C – Hub-Spoke + Azure Firewall + Active-Active VPN Gateway
./deploy.sh -v hub-azfw-vpngw -s <sub-id> -n "Contoso Ltd" -a CON -d contoso.local

# What-if preview (any variant)
./deploy.sh -v vwan-azfw -s <sub-id> -n "Contoso Ltd" -a CON -d contoso.local --what-if

# Management groups only
./deploy.sh -v sophos-nva -s <sub-id> -n "Contoso Ltd" -a CON -d contoso.local --mgmt-groups-only

# Primary only (no secondary region)
./deploy.sh -v hub-azfw-vpngw -s <sub-id> -n "Contoso Ltd" -a CON -d contoso.local --no-secondary
```

---

## Deploy via Azure DevOps

The pipeline in `azure-pipelines.yaml` is parameterised for all three variants.

**Select variant at queue time:**
- Go to Pipelines → Run Pipeline
- Set **Landing Zone Variant** to `sophos-nva`, `vwan-azfw`, or `hub-azfw-vpngw`
- Set **Primary Azure Region** and **Deploy Secondary Region**

**Required setup (once per organisation):**

1. Variable group `lz-deployment-secrets`:

   | Variable | Secret | Value |
   |---|---|---|
   | `AZURE_SUBSCRIPTION_ID` | No | Target subscription |
   | `ADMIN_PASSWORD` | **Yes** | VM admin password |
   | `CUSTOMER_NAME` | No | e.g. `Contoso Ltd` |
   | `CUSTOMER_ABBR` | No | e.g. `CON` |
   | `CUSTOMER_DOMAIN` | No | e.g. `contoso.local` |

2. Service connections:
   - `sc-espria-lz-tenant` — Management Group Contributor at tenant root
   - `sc-espria-lz-subscription` — Owner on target subscription

3. Environments (with approval gates):
   - `lz-management-groups`
   - `lz-production`

---

## Variant Architecture Comparison

| Aspect | A: sophos-nva | B: vwan-azfw | C: hub-azfw-vpngw |
|---|---|---|---|
| Hub type | VNet | Azure Virtual WAN hub | VNet |
| Firewall | Sophos XG NVA (VM) | Azure Firewall Premium (hub-injected) | Azure Firewall Premium (standalone) |
| VPN | Sophos XG (IPSec) | vWAN VPN GW (add-on, not deployed by default) | Active-Active VPN GW (always deployed) |
| Spoke connectivity | VNet peering (bidirectional) | Hub VNet connections (vWAN managed) | VNet peering (bidirectional) |
| Routing on spokes | UDRs → NVA LAN IP | None (vWAN routing intent) | UDRs → Azure Firewall private IP |
| Hub-to-hub | Explicit VNet peering | Automatic (vWAN global transit) | Explicit VNet peering |
| Bastion | Management RG, hub subnet | Management spoke VNet | Management RG, hub subnet |
| Firewall policy | N/A (Sophos managed) | Azure Firewall Policy (Premium) | Azure Firewall Policy (Premium) |
| NVA backup | Azure Disk Backup (BUV) | Not applicable | Not applicable |
| IDPS / TLS inspection | Sophos native | Azure Firewall IDPS (Premium) | Azure Firewall IDPS (Premium) |
| When to choose | Existing Sophos licences / preference | Large-scale, 10+ spokes, global transit required | Azure-native firewalling + site-to-site VPN |

---

## Address Space Design

All variants use the same Espria networking standard. The vWAN variant adds hub address prefixes.

| Range | Purpose |
|---|---|
| `10.101.0.0/16` | Primary region (spoke VNets) |
| `10.102.0.0/16` | Secondary region (spoke VNets) |
| `10.101.128.0/23` | Primary vWAN hub (Variant B only) |
| `10.102.128.0/23` | Secondary vWAN hub (Variant B only) |

Spoke VNet address allocations (all variants):

| VNet | Primary | Secondary |
|---|---|---|
| Connectivity hub | `10.101.0.0/21` | `10.102.0.0/21` |
| Identity spoke | `10.101.8.0/22` | `10.102.8.0/22` |
| Management spoke | `10.101.248.0/21` | `10.102.248.0/21` |

---

## Entra Domain Services (Future Branch)

The `shared/identity/entrads/` folder contains the placeholder module and detailed design notes for Entra DS variants. Branch naming convention:

```
feature/entrads-sophos-nva
feature/entrads-vwan-azfw
feature/entrads-hub-azfw-vpngw
```

Key differences when implementing Entra DS variants:
- Replace `../../shared/identity/adds/identityVnet.bicep` with `../../shared/identity/entrads/entraDomainServices.bicep` in each variant's `main.bicep`
- Domain name must be routable (e.g. `aadds.contoso.com`) — `.local` not supported
- No VM backup needed for identity layer (Microsoft-managed)
- DNS IPs retrieved post-provisioning (not available at Bicep deploy time)
- Replica set in secondary region uses a separate subnet in the same managed domain

---

## Post-Deployment Steps

All variants require these steps after Bicep deployment completes:

| Step | Sophos NVA | vWAN + AZFW | AZFW + VPN GW |
|---|---|---|---|
| AD DS promotion | Required | Required | Required |
| Firewall policy / rules | Sophos UI | Azure portal / Bicep update | Azure portal / Bicep update |
| VPN peer config | Sophos IPSec | vWAN VPN site (add separately) | Local Network Gateway + Connection |
| Backup RBAC (BUV MSI) | Required (NVA disk) | Not needed | Not needed |
| ASR initial sync | Required (MGMT VM) | Required (MGMT VM) | Required (MGMT VM) |
| Defender for Cloud | Recommended | Recommended | Recommended |
| NinjaOne agent | All VMs | All VMs | All VMs |
| Tenable | Connect subscription | Connect subscription | Connect subscription |

---

*Maintained by Espria Solutions Architecture.*

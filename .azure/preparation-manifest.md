# Azure Deployment Preparation Manifest
**Project:** Espria Azure Base Landing Zone  
**Recipe:** Bicep (subscription-scope)  
**Status:** Validated  
**Last Updated:** 2026-05-26

## Configuration

| Field | Value |
|---|---|
| Subscription | Configured via `AZURE_SUBSCRIPTION_ID` (DevOps) or `-s` flag (CLI) |
| Primary Region | `uksouth` (default, overridable via parameter) |
| Scope | Subscription |
| IaC Tool | Azure Bicep |
| Pipeline | Azure DevOps (`azure-pipelines.yaml`) |

## Variants

| Folder | Identity | Connectivity | ARM Template |
|---|---|---|---|
| `variants/sophos-nva/` | IaaS AD DS | Hub-Spoke + Sophos XG NVA | `azuredeploy.json` ✅ |
| `variants/vwan-azfw/` | IaaS AD DS | vWAN + Azure Firewall | `azuredeploy.json` ✅ |
| `variants/hub-azfw-vpngw/` | IaaS AD DS | Hub-Spoke + Azure Firewall + VPN GW (optional) | `azuredeploy.json` ✅ |
| `variants/sophos-nva-entrads/` | Entra DS | Hub-Spoke + Sophos XG NVA | `azuredeploy.json` ✅ |
| `variants/vwan-azfw-entrads/` | Entra DS | vWAN + Azure Firewall | `azuredeploy.json` ✅ |
| `variants/hub-azfw-vpngw-entrads/` | Entra DS | Hub-Spoke + Azure Firewall + VPN GW (optional) | `azuredeploy.json` ✅ |

## Shared Modules

| Path | Purpose |
|---|---|
| `shared/governance/managementGroups.bicep` | CAF MG hierarchy (tenant scope) |
| `shared/governance/resourceGroups.bicep` | Core RGs (subscription scope) |
| `shared/governance/policies.bicep` | 9× policy assignments (subscription scope) |
| `shared/identity/adds/identityVnet.bicep` | IaaS AD DS — DCs + identity VNet |
| `shared/identity/entrads/entraDomainServices.bicep` | Entra DS — managed domain + identity VNet |
| `shared/management/managementVnet.bicep` | Management spoke + VM + Bastion |
| `shared/backup/backupAndRecovery.bicep` | RSV (VM Backup) + Backup Vault (Disk) |
| `shared/backup/asrReplication.bicep` | ASR A2A — Management VM |
| `shared/backup/asrCacheStorage.bicep` | ASR staging storage account |
| `shared/monitoring/centralMonitoring.bicep` | LAW + VM Insights + AMA + Action Group |

## Validation Results

| Check | Result |
|---|---|
| Bicep module paths (all 6 variants) | ✅ Pass |
| targetScope consistency | ✅ Pass |
| @secure() on adminPassword | ✅ Pass |
| Balanced braces | ✅ Pass |
| ARM JSON structure (all 6 files) | ✅ Pass |
| Entra DS NSG mandatory rules | ✅ Present |
| VPN Gateway optional flag | ✅ Present in both variants |
| vWAN hub address auto-derive | ✅ 10.{siteId}.0.0/23 |

## Deployment Commands

```bash
# Bicep – CLI (recommended)
./deploy.sh -v <variant> -s <sub-id> -n "Customer Ltd" -a CUST -d domain.com

# Bicep – Azure CLI direct
az deployment sub create \
  --location uksouth \
  --template-file variants/<variant>/main.bicep \
  --parameters variants/<variant>/main.parameters.json \
    adminPassword="<password>" customerName="Customer Ltd" \
    customerAbbreviation="CUST" customerDomainName="domain.com"

# Preview
az deployment sub what-if --location uksouth \
  --template-file variants/<variant>/main.bicep \
  --parameters variants/<variant>/main.parameters.json
```

## Prerequisites

- Azure CLI ≥ 2.55 with `az bicep install`
- Owner on target subscription
- Management Group Contributor at tenant root
- Sophos XG Marketplace terms accepted (sophos-nva variants only)
- Entra DS: domain verified in Entra ID, Entra ID P1/P2 licences (entrads variants)

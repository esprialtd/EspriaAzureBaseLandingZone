# Espria Azure Landing Zone (Bicep)

This repository provides a modular Bicep-based implementation of a secure and scalable Azure Landing Zone tailored for **Espria**'s multi-subscription enterprise architecture.

---

## 📐 Overview

The landing zone provisions the following:

- **Management Groups**
- **Hub-and-Spoke Virtual Network Topology**
- **Azure firewall with Virtual Network Gateway**
- **Relivant Routing**
- **Core Identity (Domain Controllers, AADDS)**
- **Management (Azure Bastion, Jump VM)**
- **Shared Services (File/Print Servers, Azure Files)**
- **Automated Tagging**
- **Private Endpoints & DNS**
- **NSG Association to Subnets**
- **Management Groups**

---

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fesprialtd%2FEspriaAzureBaseLandingZone%2Fmain%2Fmain.json)



## 🗂️ Directory Structure

├── main.bicep                     # Root orchestration template
├── main.parameters.json          # Default parameter values
├── modules/
│   ├── connectivity/
│   │   ├── connectivityCoreConnectivity.bicep
│   │   ├── azFirewall.bicep
│   │   ├── vNetGateway.bicep
│   ├── identity/
│   │   ├── aadds.bicep
│   │   ├── domainVms.bicep
│   │   ├── connectivityCoreIdentity.bicep
│   ├── shared/
│   │   ├── azureFiles.bicep
│   │   ├── fileServer.bicep
│   │   ├── printServer.bicep
│   │   ├── connectivitySharedServices.bicep
│   ├── management/
│   │   ├── managementVm.bicep
│   │   ├── connectivityCoreManagement.bicep
│   ├── managementGroups.bicep

---

## Parameters
| Name                   | Description                              | Example              |
| ---------------------- | ---------------------------------------- | -------------------- |
| `customerName`         | Full name of the customer                | `Espria`             |
| `customerAbbreviation` | Abbreviation used for naming conventions | `ESP`                |
| `region`               | Azure region for deployment              | `uksouth`            |
| `environment`          | Environment type                         | `prod`, `dev`, `uat` |
| `coreSubscriptionId`   | Subscription ID for core services        |                      |
| `sharedSubscriptionId` | Subscription ID for shared services      |                      |
| `adminUsername`        | VM admin username                        |                      |
| `adminPassword`        | VM admin password (secure string)        |                      |

## Outputs
- VNet IDs for core, identity, management, and shared networks
- Azure Firewall and VPN Gateway IDs and IPs
- VM and service resource IDs for tracking and integration

## Notes
- Ensure address spaces do not overlap with on-prem networks.
- Adjust route tables and firewall policies as needed for additional security or NVA integrations.

## Prerequisites
- Azure CLI or PowerShell
- Bicep CLI (v0.19+)
- Sufficient permissions to deploy resource groups, network resources, and management groups

## 🚀 Deployment

```bash
az deployment sub create \
  --location uksouth \
  --template-file main.bicep \
  --parameters @main.parameters.json
💡 Use the --subscription flag to deploy to a specific subscription if needed.
```
##  🔐 Secrets
Ensure a Key Vault is provisioned with a secret named AdminPassword. Reference it in main.parameters.json.

## 🏷 Tagging Policy
All resources are tagged with:

CreatedBy, ManagedBy, Environment, Location

Resource-specific: Application, Function, CostCenter

## 🧩 Module Extensibility
You can extend the base modules to support:

- Custom route tables
- ExpressRoute/VPN Gateways
- Monitoring and policies

## 📞 Support
For deployment issues or enhancements, please contact the internal Azure platform team at platform@espria.com
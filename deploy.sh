#!/usr/bin/env bash
# =============================================================================
# Espria Azure Landing Zone – Multi-Variant Deployment Script
# Usage: ./deploy.sh -v <variant> -s <subscription-id> -n <name> -a <abbr> -d <domain>
# =============================================================================
set -euo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────
VARIANT="sophos-nva"
SUBSCRIPTION=""
CUSTOMER_NAME=""
CUSTOMER_ABBR=""
CUSTOMER_DOMAIN=""
PRIMARY_REGION="uksouth"
SECONDARY_REGION="auto"
ENVIRONMENT="prod"
ADMIN_USER="espria-admin"
VPN_GW_SKU="VpnGw1AZ"
FW_SKU="Premium"
DEPLOY_SECONDARY=true
WHAT_IF=false
MGMT_GROUPS_ONLY=false

BOLD="\033[1m"; RED="\033[0;31m"; GREEN="\033[0;32m"; YELLOW="\033[1;33m"; CYAN="\033[0;36m"; RESET="\033[0m"

usage() {
  echo -e "${BOLD}Espria Azure Landing Zone – Multi-Variant Deploy${RESET}"
  echo ""
  echo "Usage: $0 -v <variant> -s <sub-id> -n <name> -a <abbr> -d <domain> [options]"
  echo ""
  echo -e "${BOLD}Required:${RESET}"
  echo "  -v  Variant: sophos-nva | vwan-azfw | hub-azfw-vpngw
             sophos-nva-entrads | vwan-azfw-entrads | hub-azfw-vpngw-entrads"
  echo "  -s  Azure subscription ID"
  echo "  -n  Customer full name (e.g. \"Contoso Ltd\")"
  echo "  -a  Customer abbreviation, max 5 chars (e.g. CON)"
  echo "  -d  AD domain name (e.g. contoso.local)"
  echo ""
  echo -e "${BOLD}Optional:${RESET}"
  echo "  -p  Primary region (default: uksouth)"
  echo "  -r  Secondary region (default: auto)"
  echo "  -e  Environment: prod|dev|uat (default: prod)"
  echo "  -u  Admin username (default: espria-admin)"
  echo "  --fw-sku     Firewall SKU: Premium|Standard (default: Premium)"
  echo "  --vpn-sku    VPN GW SKU: VpnGw1AZ|VpnGw2AZ (default: VpnGw1AZ)"
  echo "  --no-secondary    Skip secondary region"
  echo "  --what-if         Preview only, no deployment"
  echo "  --mgmt-groups-only  Deploy management groups only"
  echo ""
  echo -e "${BOLD}Examples:${RESET}"
  echo "  # Sophos NVA (default)"
  echo "  ./deploy.sh -v sophos-nva -s 000... -n \"Contoso Ltd\" -a CON -d contoso.local"
  echo ""
  echo "  # vWAN + Azure Firewall"
  echo "  ./deploy.sh -v vwan-azfw -s 000... -n \"Contoso Ltd\" -a CON -d contoso.local"
  echo ""
  echo "  # Hub-Spoke + Azure Firewall + Active-Active VPN Gateway"
  echo "  ./deploy.sh -v hub-azfw-vpngw -s 000... -n \"Contoso Ltd\" -a CON -d contoso.local"
  echo ""
  echo "  # What-if preview"
  echo "  ./deploy.sh -v vwan-azfw -s 000... -n \"Contoso Ltd\" -a CON -d contoso.local --what-if"
}

# ── Parse arguments ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    -v) VARIANT="$2"; shift 2 ;;
    -s) SUBSCRIPTION="$2"; shift 2 ;;
    -n) CUSTOMER_NAME="$2"; shift 2 ;;
    -a) CUSTOMER_ABBR="$2"; shift 2 ;;
    -d) CUSTOMER_DOMAIN="$2"; shift 2 ;;
    -p) PRIMARY_REGION="$2"; shift 2 ;;
    -r) SECONDARY_REGION="$2"; shift 2 ;;
    -e) ENVIRONMENT="$2"; shift 2 ;;
    -u) ADMIN_USER="$2"; shift 2 ;;
    --fw-sku) FW_SKU="$2"; shift 2 ;;
    --vpn-sku) VPN_GW_SKU="$2"; shift 2 ;;
    --no-secondary) DEPLOY_SECONDARY=false; shift ;;
    --what-if) WHAT_IF=true; shift ;;
    --mgmt-groups-only) MGMT_GROUPS_ONLY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# ── Validate required args ────────────────────────────────────────────────────
[[ "$VARIANT" =~ ^(sophos-nva|vwan-azfw|hub-azfw-vpngw|sophos-nva-entrads|vwan-azfw-entrads|hub-azfw-vpngw-entrads)$ ]] || { echo -e "${RED}Invalid variant: $VARIANT${RESET}"; exit 1; }
[[ -n "$SUBSCRIPTION" && -n "$CUSTOMER_NAME" && -n "$CUSTOMER_ABBR" && -n "$CUSTOMER_DOMAIN" ]] || { usage; exit 1; }

BICEP_FILE="$(dirname "$0")/variants/${VARIANT}/main.bicep"
PARAMS_FILE="$(dirname "$0")/variants/${VARIANT}/main.parameters.json"

[[ -f "$BICEP_FILE" ]] || { echo -e "${RED}Bicep file not found: $BICEP_FILE${RESET}"; exit 1; }

# ── Password prompt (never passed as CLI arg) ─────────────────────────────────
if [[ -z "${ADMIN_PASSWORD:-}" ]]; then
  echo -e "${YELLOW}Enter VM admin password (min 12 chars, upper+lower+number+symbol):${RESET}"
  read -rs ADMIN_PASSWORD
  echo ""
  [[ ${#ADMIN_PASSWORD} -ge 12 ]] || { echo -e "${RED}Password too short (min 12 chars)${RESET}"; exit 1; }
fi

# ── Set subscription ──────────────────────────────────────────────────────────
echo -e "${CYAN}Setting subscription: $SUBSCRIPTION${RESET}"
az account set --subscription "$SUBSCRIPTION"

# ── Accept Sophos Marketplace terms (sophos-nva only) ────────────────────────
if [[ ("$VARIANT" == "sophos-nva" || "$VARIANT" == "sophos-nva-entrads") && "$WHAT_IF" == "false" && "$MGMT_GROUPS_ONLY" == "false" ]]; then
  echo -e "${CYAN}Accepting Sophos XG Marketplace terms...${RESET}"
  az vm image terms accept --publisher sophos --offer sophos-xg --plan byol \
    --subscription "$SUBSCRIPTION" 2>/dev/null || true
fi

# ── Common parameters ─────────────────────────────────────────────────────────
COMMON_PARAMS=(
  "customerName=$CUSTOMER_NAME"
  "customerAbbreviation=$CUSTOMER_ABBR"
  "customerDomainName=$CUSTOMER_DOMAIN"
  "adminUsername=$ADMIN_USER"
  "adminPassword=$ADMIN_PASSWORD"
  "primaryRegion=$PRIMARY_REGION"
  "secondaryRegion=$SECONDARY_REGION"
  "deploySecondaryRegion=$DEPLOY_SECONDARY"
  "environment=$ENVIRONMENT"
)

# Variant-specific extra params
if [[ "$VARIANT" == "hub-azfw-vpngw" ]]; then
  COMMON_PARAMS+=("vpnGwSku=$VPN_GW_SKU" "firewallSkuTier=$FW_SKU")
fi
if [[ "$VARIANT" == "vwan-azfw" ]]; then
  COMMON_PARAMS+=("firewallSkuTier=$FW_SKU")
fi

# ── Management groups only ────────────────────────────────────────────────────
if [[ "$MGMT_GROUPS_ONLY" == "true" ]]; then
  echo -e "${CYAN}Deploying Management Groups only...${RESET}"
  az deployment tenant create \
    --location "$PRIMARY_REGION" \
    --template-file "$(dirname "$0")/shared/governance/managementGroups.bicep" \
    --parameters customerName="$CUSTOMER_NAME" customerAbbreviation="$CUSTOMER_ABBR"
  echo -e "${GREEN}✅ Management Groups deployed${RESET}"
  exit 0
fi

DEPLOYMENT_CMD="az deployment sub"
DEPLOYMENT_NAME="espria-lz-${VARIANT}-$(date +%Y%m%d%H%M%S)"

if [[ "$WHAT_IF" == "true" ]]; then
  echo -e "${CYAN}Running what-if preview for variant: ${BOLD}$VARIANT${RESET}"
  $DEPLOYMENT_CMD what-if \
    --location "$PRIMARY_REGION" \
    --template-file "$BICEP_FILE" \
    --parameters "$PARAMS_FILE" "${COMMON_PARAMS[@]}" \
    --result-format FullResourcePayloads
else
  echo -e "${CYAN}Deploying variant: ${BOLD}$VARIANT${RESET}"
  echo -e "  Customer:  $CUSTOMER_NAME ($CUSTOMER_ABBR)"
  echo -e "  Region:    $PRIMARY_REGION → $SECONDARY_REGION"
  echo -e "  Env:       $ENVIRONMENT"
  echo ""
  $DEPLOYMENT_CMD create \
    --location "$PRIMARY_REGION" \
    --name "$DEPLOYMENT_NAME" \
    --template-file "$BICEP_FILE" \
    --parameters "$PARAMS_FILE" "${COMMON_PARAMS[@]}"
  echo -e "${GREEN}✅ Deployment complete: $DEPLOYMENT_NAME${RESET}"
fi

#!/usr/bin/env bash
# =============================================================================
# Espria Azure Base Landing Zone – One-Click Deployment Script
# =============================================================================
# Usage:
#   ./deploy.sh [options]
#
# Options:
#   -s  SUBSCRIPTION_ID      Target Azure subscription ID (required)
#   -n  CUSTOMER_NAME        Customer full name (e.g., "Contoso Ltd")
#   -a  CUSTOMER_ABBR        Customer abbreviation (e.g., CON)
#   -d  DOMAIN_NAME          AD domain name (e.g., contoso.local)
#   -p  PRIMARY_REGION       Primary region (default: uksouth)
#   -r  SECONDARY_REGION     Secondary region (default: ukwest)
#   -e  ENVIRONMENT          Environment (default: prod)
#   -u  ADMIN_USERNAME       VM admin username (default: espria-admin)
#       --no-secondary       Skip secondary region deployment
#       --what-if            Run what-if only, do not deploy
#       --mgmt-groups-only   Deploy management groups only
#
# Examples:
#   ./deploy.sh -s 00000000-0000-0000-0000-000000000000 -n "Contoso Ltd" -a CON -d contoso.local
#   ./deploy.sh -s ... -n ... -a ... -d ... --what-if
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
SUBSCRIPTION_ID=""
CUSTOMER_NAME=""
CUSTOMER_ABBR=""
DOMAIN_NAME=""
PRIMARY_REGION="uksouth"
SECONDARY_REGION="ukwest"
ENVIRONMENT="prod"
ADMIN_USERNAME="espria-admin"
DEPLOY_SECONDARY="true"
WHAT_IF_ONLY="false"
MGMT_GROUPS_ONLY="false"
LOCATION="uksouth"
DEPLOYMENT_NAME="espria-base-lz"
TIMESTAMP=$(date +%Y%m%d%H%M%S)

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*"; exit 1; }

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case $1 in
    -s) SUBSCRIPTION_ID="$2"; shift 2 ;;
    -n) CUSTOMER_NAME="$2";   shift 2 ;;
    -a) CUSTOMER_ABBR="$2";   shift 2 ;;
    -d) DOMAIN_NAME="$2";     shift 2 ;;
    -p) PRIMARY_REGION="$2";  shift 2 ;;
    -r) SECONDARY_REGION="$2";shift 2 ;;
    -e) ENVIRONMENT="$2";     shift 2 ;;
    -u) ADMIN_USERNAME="$2";  shift 2 ;;
    --no-secondary)   DEPLOY_SECONDARY="false"; shift ;;
    --what-if)        WHAT_IF_ONLY="true";      shift ;;
    --mgmt-groups-only) MGMT_GROUPS_ONLY="true"; shift ;;
    *) error "Unknown argument: $1" ;;
  esac
done

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
[[ -z "$SUBSCRIPTION_ID" ]] && error "Subscription ID (-s) is required"
[[ -z "$CUSTOMER_NAME"   ]] && error "Customer name (-n) is required"
[[ -z "$CUSTOMER_ABBR"   ]] && error "Customer abbreviation (-a) is required"
[[ -z "$DOMAIN_NAME"     ]] && error "Domain name (-d) is required"

CUSTOMER_ABBR_UPPER=$(echo "$CUSTOMER_ABBR" | tr '[:lower:]' '[:upper:]')

# ---------------------------------------------------------------------------
# Print summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Espria Azure Base Landing Zone Deployment"
echo "============================================================"
info "Customer       : $CUSTOMER_NAME ($CUSTOMER_ABBR_UPPER)"
info "Domain         : $DOMAIN_NAME"
info "Subscription   : $SUBSCRIPTION_ID"
info "Primary Region : $PRIMARY_REGION"
info "Secondary      : ${SECONDARY_REGION} (deploy: $DEPLOY_SECONDARY)"
info "Environment    : $ENVIRONMENT"
info "What-If Only   : $WHAT_IF_ONLY"
echo "============================================================"
echo ""

# ---------------------------------------------------------------------------
# Prompt for admin password (never stored in params file)
# ---------------------------------------------------------------------------
read -rsp "Enter VM admin password (will not be echoed): " ADMIN_PASSWORD
echo ""
[[ -z "$ADMIN_PASSWORD" ]] && error "Admin password cannot be empty"

# Password complexity check
if [[ ${#ADMIN_PASSWORD} -lt 12 ]]; then
  error "Password must be at least 12 characters"
fi

# ---------------------------------------------------------------------------
# Pre-flight: ensure Bicep installed
# ---------------------------------------------------------------------------
info "Installing/updating Bicep..."
az bicep install
az bicep version

# ---------------------------------------------------------------------------
# Step 1: Lint
# ---------------------------------------------------------------------------
info "Linting Bicep files..."
az bicep lint --file main.bicep
success "Lint passed"

# ---------------------------------------------------------------------------
# Step 2: Accept Sophos Marketplace terms
# ---------------------------------------------------------------------------
if [[ "$WHAT_IF_ONLY" == "false" && "$MGMT_GROUPS_ONLY" == "false" ]]; then
  info "Accepting Sophos XG Marketplace terms..."
  az vm image terms accept \
    --publisher sophos \
    --offer sophos-xg \
    --plan byol \
    --subscription "$SUBSCRIPTION_ID" 2>/dev/null && success "Marketplace terms accepted" || warn "Could not accept terms (may already be accepted)"
fi

# ---------------------------------------------------------------------------
# Step 3: Deploy Management Groups (tenant scope)
# ---------------------------------------------------------------------------
if [[ "$WHAT_IF_ONLY" == "false" ]]; then
  info "Deploying Management Group hierarchy..."
  az deployment tenant create \
    --name "${DEPLOYMENT_NAME}-mgmtgroups-${TIMESTAMP}" \
    --location "$LOCATION" \
    --template-file "modules/governance/managementGroups.bicep" \
    --parameters \
      customerName="$CUSTOMER_NAME" \
      customerAbbreviation="$CUSTOMER_ABBR_UPPER"
  success "Management Groups deployed"
fi

[[ "$MGMT_GROUPS_ONLY" == "true" ]] && { success "Management groups only – done."; exit 0; }

# ---------------------------------------------------------------------------
# Step 4: What-If or Full Deploy
# ---------------------------------------------------------------------------
COMMON_PARAMS=(
  customerName="$CUSTOMER_NAME"
  customerAbbreviation="$CUSTOMER_ABBR_UPPER"
  customerDomainName="$DOMAIN_NAME"
  primaryRegion="$PRIMARY_REGION"
  secondaryRegion="$SECONDARY_REGION"
  deploySecondaryRegion="$DEPLOY_SECONDARY"
  environment="$ENVIRONMENT"
  adminUsername="$ADMIN_USERNAME"
  adminPassword="$ADMIN_PASSWORD"
)

if [[ "$WHAT_IF_ONLY" == "true" ]]; then
  info "Running What-If analysis..."
  az deployment sub what-if \
    --name "${DEPLOYMENT_NAME}-whatif-${TIMESTAMP}" \
    --location "$LOCATION" \
    --subscription "$SUBSCRIPTION_ID" \
    --template-file main.bicep \
    --parameters "@main.parameters.json" \
    --parameters "${COMMON_PARAMS[@]}" \
    --result-format FullResourcePayloads
  success "What-If complete. Review changes above before deploying."
  exit 0
fi

info "Deploying Landing Zone to subscription $SUBSCRIPTION_ID..."
az deployment sub create \
  --name "${DEPLOYMENT_NAME}-${TIMESTAMP}" \
  --location "$LOCATION" \
  --subscription "$SUBSCRIPTION_ID" \
  --template-file main.bicep \
  --parameters "@main.parameters.json" \
  --parameters "${COMMON_PARAMS[@]}" \
  --output json | tee "deployment-output-${TIMESTAMP}.json"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
success "Landing Zone deployment complete!"
echo "Outputs:"
cat "deployment-output-${TIMESTAMP}.json" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    props = d.get('properties', {}).get('outputs', {})
    for k, v in props.items():
        print(f'  {k}: {v.get(\"value\", \"\")}')
except:
    print('  (see deployment-output-${TIMESTAMP}.json)')
" 2>/dev/null || true
echo "============================================================"

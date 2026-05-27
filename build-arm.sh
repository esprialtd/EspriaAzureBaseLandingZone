#!/usr/bin/env bash
# =============================================================================
# Espria Azure Landing Zone – ARM Template Builder
# Compiles all six variant main.bicep files to azuredeploy.json using az bicep.
#
# Run this locally after any change to Bicep source before pushing to the repo.
# The DevOps pipeline also runs this automatically on merge to main.
#
# Prerequisites:
#   az bicep install      (run once)
#   az login              (must be authenticated)
#
# Usage:
#   ./build-arm.sh                  # build all 6 variants
#   ./build-arm.sh -v sophos-nva    # build one variant only
# =============================================================================
set -euo pipefail

BOLD="\033[1m"; GREEN="\033[0;32m"; RED="\033[0;31m"; CYAN="\033[0;36m"; RESET="\033[0m"
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

VARIANTS=(
  sophos-nva
  vwan-azfw
  hub-azfw-vpngw
  sophos-nva-entrads
  vwan-azfw-entrads
  hub-azfw-vpngw-entrads
)

TARGET_VARIANT=""
while [[ $# -gt 0 ]]; do
  case $1 in
    -v) TARGET_VARIANT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [-v <variant>]"
      echo "Variants: ${VARIANTS[*]}"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -n "$TARGET_VARIANT" ]]; then
  VARIANTS=("$TARGET_VARIANT")
fi

echo -e "${BOLD}Espria LZ – ARM Template Build${RESET}"
echo -e "Bicep version: $(az bicep version 2>/dev/null || echo 'not installed')\n"

PASS=0; FAIL=0

for variant in "${VARIANTS[@]}"; do
  bicep_file="$REPO_ROOT/variants/$variant/main.bicep"
  out_file="$REPO_ROOT/variants/$variant/azuredeploy.json"

  if [[ ! -f "$bicep_file" ]]; then
    echo -e "  ${RED}SKIP${RESET}  $variant — main.bicep not found"
    ((FAIL++)); continue
  fi

  echo -ne "  ${CYAN}Building${RESET}  $variant ... "
  if az bicep build --file "$bicep_file" --outfile "$out_file" 2>/tmp/bicep_err; then
    size=$(wc -c < "$out_file")
    echo -e "${GREEN}✅  $(( size / 1024 ))KB${RESET}"
    ((PASS++))
  else
    echo -e "${RED}❌  FAILED${RESET}"
    cat /tmp/bicep_err
    ((FAIL++))
  fi
done

echo ""
echo -e "PASS: ${PASS}  FAIL: ${FAIL}"
[[ $FAIL -eq 0 ]] || exit 1
echo -e "${GREEN}All ARM templates built. Commit variants/*/azuredeploy.json to the repo.${RESET}"

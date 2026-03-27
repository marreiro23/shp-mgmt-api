#!/bin/bash

###############################################################################
# API Test Script - shp-mgmt-api
# 
# Testa todos os endpoints da API com exemplos práticos
# Uso: bash api-tests.sh [API_URL] [OPERATION]
# 
# Exemplo:
#   bash api-tests.sh http://localhost:3001 health
#   bash api-tests.sh http://localhost:3001 sites
#   bash api-tests.sh http://localhost:3001 create-root-site
###############################################################################

API_URL="${1:-http://localhost:3001}"
API_PREFIX="${API_URL}/api/v1/sharepoint"
OPERATION="${2:-all}"

# Cores para output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Contadores de testes
PASSED=0
FAILED=0

function print_header() {
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

function print_test() {
  echo -e "${YELLOW}[TEST]${NC} $1"
}

function print_success() {
  echo -e "${GREEN}[PASS]${NC} $1"
  ((PASSED++))
}

function print_error() {
  echo -e "${RED}[FAIL]${NC} $1"
  ((FAILED++))
}

function test_endpoint() {
  local name=$1
  local method=$2
  local endpoint=$3
  local body=$4
  local expected_status=${5:-200}

  print_test "$method $endpoint"
  
  if [ -z "$body" ]; then
    response=$(curl -s -w "\n%{http_code}" -X "$method" "$API_PREFIX$endpoint" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json")
  else
    response=$(curl -s -w "\n%{http_code}" -X "$method" "$API_PREFIX$endpoint" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "$body")
  fi

  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -1)

  if [ "$http_code" = "$expected_status" ]; then
    print_success "$name (HTTP $http_code)"
    echo "  Response: $body" | head -c 150
    echo ""
  else
    print_error "$name (Expected $expected_status, got $http_code)"
    echo "  Response: $body" | head -c 200
    echo ""
  fi
}

function run_health_tests() {
  print_header "1. Health & Configuration Tests"
  
  test_endpoint "Health Check" "GET" "/../../health" "" 200
  test_endpoint "API Config" "GET" "/config" "" 200
}

function run_site_tests() {
  print_header "2. SharePoint Sites Tests"
  
  test_endpoint "List Sites" "GET" "/sites" "" 200
  test_endpoint "List Sites (top=5)" "GET" "/sites?top=5" "" 200
  test_endpoint "List Sites (search)" "GET" "/sites?search=marketing&top=10" "" 200
}

function run_group_tests() {
  print_header "3. Microsoft 365 Groups Tests"
  
  test_endpoint "List Groups" "GET" "/groups" "" 200
  test_endpoint "List Groups (top=5)" "GET" "/groups?top=5" "" 200
}

function run_user_tests() {
  print_header "4. Entra ID Users Tests"
  
  test_endpoint "List Users" "GET" "/users" "" 200
  test_endpoint "List Users (search=admin)" "GET" "/users?search=admin" "" 200
  test_endpoint "List Users (top=10)" "GET" "/users?top=10" "" 200
}

function run_teams_tests() {
  print_header "5. Microsoft Teams Tests"
  
  test_endpoint "List Teams" "GET" "/teams" "" 200
  test_endpoint "List Teams (search)" "GET" "/teams?search=dev" "" 200
}

function run_sync_tests() {
  print_header "6. Resource Synchronization Tests"
  
  test_endpoint "Get Sync Status" "GET" "/sync/status" "" 200
}

function run_database_tests() {
  print_header "7. Database Records Tests"
  
  test_endpoint "Get DB Sites" "GET" "/database/records?table=sharepoint_sites&limit=5" "" 200
  test_endpoint "Get DB Users" "GET" "/database/records?table=sharepoint_users&limit=5" "" 200
  test_endpoint "Get DB Groups" "GET" "/database/records?table=sharepoint_groups&limit=5" "" 200
  test_endpoint "Get DB Teams" "GET" "/database/records?table=sharepoint_teams&limit=5" "" 200
}

function run_create_site_subsite_tests() {
  print_header "8. Create Subsite Tests (requires valid parentSiteId)"
  
  # Este teste requer um parentSiteId real
  # Substitua pela ID de um site real em seu ambiente
  PARENT_SITE_ID="example-parent-site-id"
  
  if [ "$PARENT_SITE_ID" = "example-parent-site-id" ]; then
    echo -e "${YELLOW}[SKIP]${NC} Create Subsite tests (requires real parentSiteId)"
    echo "       Set PARENT_SITE_ID environment variable to run these tests"
    return
  fi
  
  local timestamp=$(date +%s)
  local subsite_name="subsite-test-${timestamp}"
  
  local body=$(cat <<EOF
{
  "displayName": "Test Subsite ${timestamp}",
  "name": "$subsite_name",
  "description": "Test subsite created via API",
  "createType": "subsite"
}
EOF
)
  
  test_endpoint "Create Subsite" "POST" "/sites/${PARENT_SITE_ID}/sites" "$body" 201
}

function run_create_root_site_tests() {
  print_header "9. Create Root Site Tests"
  
  # Este teste requer permissões elevadas de admin
  echo -e "${YELLOW}[INFO]${NC} Root site creation requires admin permissions"
  echo "       Using this payload example:"
  
  cat <<'EOF'
  {
    "displayName": "Global Marketing",
    "name": "gm-root",
    "description": "Root site for global marketing",
    "createType": "root",
    "template": "STS#3"
  }
EOF
  
  echo ""
  echo -e "${YELLOW}CURL Example:${NC}"
  cat <<'EOF'
  curl -X POST http://localhost:3001/api/v1/sharepoint/sites/unused-param/sites \
    -H "Content-Type: application/json" \
    -d '{
      "displayName": "Global Marketing",
      "name": "gm-root",
      "createType": "root",
      "template": "STS#3"
    }'
EOF
  
  echo ""
}

function run_clone_site_tests() {
  print_header "10. Clone Site Tests"
  
  echo -e "${YELLOW}[INFO]${NC} Site cloning requires a valid source site ID"
  echo "       Using this payload example:"
  
  cat <<'EOF'
  {
    "displayName": "Marketing Clone",
    "name": "marketing-clone",
    "description": "Clone of existing marketing site",
    "createType": "clone",
    "cloneFromSiteId": "source-site-id-here",
    "parentSiteId": "optional-parent-for-subsite"
  }
EOF
  
  echo ""
  echo -e "${YELLOW}CURL Example:${NC}"
  cat <<'EOF'
  curl -X POST http://localhost:3001/api/v1/sharepoint/sites/unused-param/sites \
    -H "Content-Type: application/json" \
    -d '{
      "displayName": "Marketing Clone",
      "name": "marketing-clone",
      "createType": "clone",
      "cloneFromSiteId": "existing-site-id-here"
    }'
EOF
  
  echo ""
}

function print_summary() {
  echo ""
  print_header "Test Summary"
  echo -e "${GREEN}Passed: $PASSED${NC}"
  echo -e "${RED}Failed: $FAILED${NC}"
  
  total=$((PASSED + FAILED))
  if [ $total -gt 0 ]; then
    percentage=$((PASSED * 100 / total))
    echo -e "Success Rate: ${YELLOW}${percentage}%${NC}"
  fi
}

# Main execution
case "$OPERATION" in
  "health")
    run_health_tests
    ;;
  "sites")
    run_site_tests
    ;;
  "groups")
    run_group_tests
    ;;
  "users")
    run_user_tests
    ;;
  "teams")
    run_teams_tests
    ;;
  "sync")
    run_sync_tests
    ;;
  "db")
    run_database_tests
    ;;
  "create-subsite")
    run_create_site_subsite_tests
    ;;
  "create-root-site")
    run_create_root_site_tests
    ;;
  "clone-site")
    run_clone_site_tests
    ;;
  "all")
    run_health_tests
    run_site_tests
    run_group_tests
    run_user_tests
    run_teams_tests
    run_sync_tests
    run_database_tests
    run_create_root_site_tests
    run_clone_site_tests
    ;;
  *)
    echo "Usage: $0 [api-url] [operation]"
    echo ""
    echo "Operations:"
    echo "  health           - Health & configuration tests"
    echo "  sites            - SharePoint sites tests"
    echo "  groups           - Microsoft 365 groups tests"
    echo "  users            - Entra ID users tests"
    echo "  teams            - Microsoft Teams tests"
    echo "  sync             - Resource sync service tests"
    echo "  db               - Database records tests"
    echo "  create-subsite   - Create subsite tests"
    echo "  create-root-site - Create root site tests"
    echo "  clone-site       - Clone site tests"
    echo "  all              - Run all tests (default)"
    echo ""
    echo "Examples:"
    echo "  bash api-tests.sh                           # All tests, localhost:3001"
    echo "  bash api-tests.sh http://api.example.com teams"
    echo "  bash api-tests.sh http://localhost:3001 create-root-site"
    exit 1
    ;;
esac

print_summary

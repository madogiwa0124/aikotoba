#!/usr/bin/env bash
# ============================================================
# Aikotoba API Authentication Check Script
# Prerequisites:
#   - test/dummy server is running (bin/rails s)
#   - An account has been created (see SETUP section below)
# ============================================================

set -euo pipefail

BASE_URL="http://localhost:3000"
EMAIL="api_test@example.com"
PASSWORD="password123"

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}   $*"; }
section() { echo -e "\n${YELLOW}=== $* ===${NC}"; }

assert_status() {
  local label="$1" expected="$2" actual="$3"
  if [ "$actual" -eq "$expected" ]; then
    ok "$label → HTTP $actual"
  else
    echo -e "${RED}[FAIL]${NC} $label → expected HTTP $expected, got HTTP $actual"
    exit 1
  fi
}

json_get() {
  python3 -c "import sys,json; print(json.load(sys.stdin)['$1'])"
}

curl_api() {
  curl -s -o "$TMPFILE" -w "%{http_code}" "$@"
}

# ============================================================
# SETUP: Create an account before running this script
#
#   cd test/dummy && bin/rails c
#   Aikotoba::Account.build_by(attributes: {
#     email: "api_test@example.com",
#     password: "password123"
#   }).tap { |a| u = User.new(nickname: "api_tester"); a.authenticate_target = u; u.save!; a.save! }
# ============================================================

section "1. Sign in (POST /api/sessions)"

STATUS=$(curl_api -X POST "$BASE_URL/api/sessions" \
  -H "Content-Type: application/json" \
  -d "{\"account\":{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}}")

assert_status "Sign in" 200 "$STATUS"
cat "$TMPFILE" | python3 -m json.tool

ACCESS_TOKEN=$(cat "$TMPFILE" | json_get access_token)
REFRESH_TOKEN=$(cat "$TMPFILE" | json_get refresh_token)
info "access_token  = $ACCESS_TOKEN"
info "refresh_token = $REFRESH_TOKEN"

# ============================================================
section "2. Fetch current user (GET /api/me)"

STATUS=$(curl_api -X GET "$BASE_URL/api/me" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Accept: application/json")

assert_status "GET /api/me" 200 "$STATUS"
cat "$TMPFILE" | python3 -m json.tool

# ============================================================
section "3. Refresh tokens (POST /api/sessions/refresh)"

STATUS=$(curl_api -X POST "$BASE_URL/api/sessions/refresh" \
  -H "Content-Type: application/json" \
  -d "{\"refresh_token\":\"$REFRESH_TOKEN\"}")

assert_status "Refresh tokens" 200 "$STATUS"
cat "$TMPFILE" | python3 -m json.tool

NEW_ACCESS_TOKEN=$(cat "$TMPFILE" | json_get access_token)
NEW_REFRESH_TOKEN=$(cat "$TMPFILE" | json_get refresh_token)
info "new access_token  = $NEW_ACCESS_TOKEN"
info "new refresh_token = $NEW_REFRESH_TOKEN"

# ============================================================
section "4. Access GET /api/me with new access token"

STATUS=$(curl_api -X GET "$BASE_URL/api/me" \
  -H "Authorization: Bearer $NEW_ACCESS_TOKEN" \
  -H "Accept: application/json")

assert_status "GET /api/me with new token" 200 "$STATUS"

# ============================================================
section "5. Old access token must be invalidated after refresh (expect: 401)"

STATUS=$(curl_api -X GET "$BASE_URL/api/me" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Accept: application/json")

assert_status "GET /api/me with old token (expect 401)" 401 "$STATUS"

# ============================================================
section "6. Reusing a rotated refresh token must be rejected (expect: 401)"

STATUS=$(curl_api -X POST "$BASE_URL/api/sessions/refresh" \
  -H "Content-Type: application/json" \
  -d "{\"refresh_token\":\"$REFRESH_TOKEN\"}")

assert_status "Reuse rotated refresh token (expect 401)" 401 "$STATUS"

# ============================================================
section "7. Sign out (DELETE /api/sessions/current)"

STATUS=$(curl_api -X DELETE "$BASE_URL/api/sessions/current" \
  -H "Authorization: Bearer $NEW_ACCESS_TOKEN")

assert_status "Sign out" 204 "$STATUS"

# ============================================================
section "8. Token must be invalidated after sign out (expect: 401)"

STATUS=$(curl_api -X GET "$BASE_URL/api/me" \
  -H "Authorization: Bearer $NEW_ACCESS_TOKEN" \
  -H "Accept: application/json")

assert_status "GET /api/me after sign out (expect 401)" 401 "$STATUS"

# ============================================================
section "9. Error cases"

STATUS=$(curl_api -X POST "$BASE_URL/api/sessions" \
  -H "Content-Type: application/json" \
  -d "{\"account\":{\"email\":\"$EMAIL\",\"password\":\"wrong_password\"}}")
assert_status "Sign in with wrong password (expect 401)" 401 "$STATUS"

STATUS=$(curl_api -X GET "$BASE_URL/api/me" \
  -H "Authorization: Bearer totally_invalid_token" \
  -H "Accept: application/json")
assert_status "GET /api/me with invalid token (expect 401)" 401 "$STATUS"

STATUS=$(curl_api -X GET "$BASE_URL/api/me" \
  -H "Accept: application/json")
assert_status "GET /api/me without Authorization header (expect 401)" 401 "$STATUS"

STATUS=$(curl_api -X POST "$BASE_URL/api/sessions/refresh" \
  -H "Content-Type: application/json" \
  -d '{"refresh_token":""}')
assert_status "Refresh with blank token (expect 401)" 401 "$STATUS"

# ============================================================
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN} All checks passed!${NC}"
echo -e "${GREEN}========================================${NC}"

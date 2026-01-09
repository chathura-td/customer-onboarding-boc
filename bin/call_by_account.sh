#!/bin/bash
# ENTRY POINT 2: Account -> CIF -> Profile

ACCTNO="$1"
BASE="$(cd "$(dirname "$0")" && pwd)"

# Validate input
[ -z "$ACCTNO" ] && { echo "ERROR|ACCTNO_MISSING"; exit 1; }

# Step 1: Get CIF from Account Number using the internal script
STEP1=$("$BASE/acct_to_custid.sh" "$ACCTNO")
case "$STEP1" in
  CUSTID*)
    CUSTID="${STEP1#CUSTID|}"
    ;;
  *)
    echo "$STEP1"
    exit 1
    ;;
esac

# Step 2: Use the CIF to fetch the customer profile
"$BASE/call_by_cif.sh" "$CUSTID"
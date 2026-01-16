#!/bin/bash

ACCTNO="$1"
ACCTTYPE="${2:-SV}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

[ -z "$ACCTNO" ] && { echo "ERROR|ACCTNO_MISSING"; exit 1; }

STEP1=$("$SCRIPT_DIR/account_to_custid.sh" "$ACCTNO" "$ACCTTYPE")
case "$STEP1" in
  CUSTID*)
    CUSTID="${STEP1#CUSTID|}"
    ;;
  *)
    echo "$STEP1"
    exit 1
    ;;
esac

# Call existing working API (CustPermId-based)
"$SCRIPT_DIR/customer_profile_lookup.sh" "$CUSTID"

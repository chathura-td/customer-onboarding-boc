#!/bin/bash

ACCTNO="$1"
ACCTTYPE="${2:-SV}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REQ="/tmp/acct_req_${$}.xml"
RESP="/tmp/acct_resp_${$}.xml"
LOGDIR="$ROOT_DIR/logs"
LOGFILE="$LOGDIR/api_$(date +%Y%m%d).log"
DEBUG="${DEBUG:-N}"
SKIP_SSL_VERIFY="${SKIP_SSL_VERIFY:-N}"

# Auto-detect certificate file if not explicitly set
if [ -z "$CERT_FILE" ]; then
  CERT_FILE=$(ls "$ROOT_DIR/certificate"/*.crt 2>/dev/null | head -n1)
fi

# Validate certificate exists if SSL verification is enabled
if [ "$SKIP_SSL_VERIFY" != "Y" ]; then
  if [ -z "$CERT_FILE" ] || [ ! -f "$CERT_FILE" ]; then
    echo "ERROR|CERTIFICATE_NOT_SET"
    exit 1
  fi
fi

trap "rm -f $REQ $RESP" EXIT
mkdir -p "$LOGDIR"

log() {
  echo "$(date '+%F %T') $1" >> "$LOGFILE"
}

debug() {
  [ "$DEBUG" = "Y" ] && echo "$(date '+%F %T') DEBUG: $1" >> "$LOGFILE"
}

# Validate input
if [ -z "$ACCTNO" ]; then
  echo "ERROR|ACCTNO_MISSING"
  exit 1
fi

UUID=$(uuidgen) || { echo "ERROR|UUIDGEN_FAILED"; exit 1; }

# Build request
sed -e "s/{{UUID}}/$UUID/g" \
    -e "s/{{ACCTNO}}/$ACCTNO/g" \
    -e "s/{{ACCTTYPE}}/$ACCTTYPE/g" \
    "$ROOT_DIR/requests/account_to_custid_request.xml" > "$REQ"

debug "ACCT REQUEST XML:"
debug "$(sed 's/^/  /' "$REQ")"

# Call API
if [ "$SKIP_SSL_VERIFY" = "Y" ]; then
  CURL_OPTS="-ks"
  debug "SSL: Verification DISABLED (insecure mode)"
else
  CURL_OPTS="-s --cacert $CERT_FILE"
  debug "SSL: Verification ENABLED using certificate: $CERT_FILE"
fi

HTTP_CODE=$(curl $CURL_OPTS \
  -o "$RESP" \
  -w "%{http_code}" \
  -H "Content-Type: application/xml" \
  -X POST \
  --data @"$REQ" \
  "https://hofiservcom01.bankofceylon.local/CRG_PRODUAT/crg.aspx")

log "ACCTNO=$ACCTNO ACCTTYPE=$ACCTTYPE UUID=$UUID HTTP=$HTTP_CODE"

[ "$HTTP_CODE" != "200" ] && { echo "ERROR|HTTP_$HTTP_CODE"; exit 1; }

xmllint --noout "$RESP" 2>/dev/null || { echo "ERROR|INVALID_XML"; exit 1; }

debug "ACCT RESPONSE XML:"
debug "$(sed 's/^/  /' "$RESP")"

# Extract CustPermId
CUSTID=$(xsltproc "$ROOT_DIR/xsl/account_to_custid_formatter.xsl" "$RESP" | tr -d '\n')

debug "XSL OUTPUT: $CUSTID"

case "$CUSTID" in
  CUSTID*)
    echo "$CUSTID"
    ;;
  *)
    echo "ERROR|CUSTID_NOT_FOUND"
    ;;
esac

#!/bin/bash

ACCNO="$1"
OUTPUT_FILE="/tmp/${ACCNO}_profile.txt"
STDOUT_OUTPUT="${STDOUT_OUTPUT:-N}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REQ="/tmp/req_${$}.xml"
RESP="/tmp/resp_${$}.xml"
XSL="$ROOT_DIR/xsl/customer_profile_formatter.xsl"
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
    OUTPUT="ERROR|CERTIFICATE_NOT_SET"
    echo "$OUTPUT" > "$OUTPUT_FILE"
    [ "$STDOUT_OUTPUT" = "Y" ] && echo "$OUTPUT"
    exit 1
  fi
fi

trap "rm -f $REQ $RESP" EXIT

mkdir -p "$LOGDIR"

log() {
  echo "$(date '+%F %T') $1" >> "$LOGFILE"
}

debug() {
  if [ "$DEBUG" = "Y" ]; then
    echo "$(date '+%F %T') DEBUG: $1" >> "$LOGFILE"
  fi
}

# -------------------------
# 1. Validate input
# -------------------------
if [ -z "$ACCNO" ]; then
  OUTPUT="ERROR|ACCNO_MISSING"
  echo "$OUTPUT" > "$OUTPUT_FILE"
  [ "$STDOUT_OUTPUT" = "Y" ] && echo "$OUTPUT"
  exit 1
fi

# -------------------------
# 2. Generate UUID
# -------------------------
UUID=$(uuidgen 2>/dev/null)
if [ -z "$UUID" ]; then
  OUTPUT="ERROR|UUIDGEN_FAILED"
  echo "$OUTPUT" > "$OUTPUT_FILE"
  [ "$STDOUT_OUTPUT" = "Y" ] && echo "$OUTPUT"
  exit 1
fi

debug "ACCNO=$ACCNO"
debug "UUID=$UUID"

# -------------------------
# 3. Build request XML
# -------------------------
sed -e "s/{{UUID}}/$UUID/g" \
    -e "s/{{ACCNO}}/$ACCNO/g" \
    "$ROOT_DIR/requests/customer_profile_request.xml" > "$REQ"

debug "REQUEST XML:"
debug "$(sed 's/^/  /' "$REQ")"

# -------------------------
# 4. Call API
# -------------------------
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

log "ACCNO=$ACCNO UUID=$UUID HTTP=$HTTP_CODE"

# -------------------------
# 5. HTTP validation
# -------------------------
if [ "$HTTP_CODE" != "200" ]; then
  OUTPUT="ERROR|HTTP_$HTTP_CODE"
  echo "$OUTPUT" > "$OUTPUT_FILE"
  [ "$STDOUT_OUTPUT" = "Y" ] && echo "$OUTPUT"
  exit 1
fi

# -------------------------
# 6. XML validation
# -------------------------
if ! xmllint --noout "$RESP" 2>/dev/null; then
  debug "RAW RESPONSE (INVALID XML):"
  debug "$(sed 's/^/  /' "$RESP")"
  OUTPUT="ERROR|INVALID_XML_RESPONSE"
  echo "$OUTPUT" > "$OUTPUT_FILE"
  [ "$STDOUT_OUTPUT" = "Y" ] && echo "$OUTPUT"
  exit 1
fi

debug "RESPONSE XML:"
debug "$(sed 's/^/  /' "$RESP")"

# -------------------------
# 7. XSLT Transform
# -------------------------
XSL_OUTPUT=$(xsltproc "$XSL" "$RESP" 2>>"$LOGFILE" | tr -d '\n')

debug "XSL OUTPUT: $XSL_OUTPUT"

# -------------------------
# 8. Final guard and output
# -------------------------
case "$XSL_OUTPUT" in
  SUCCESS*|NOT_FOUND*|ERROR*)
    echo "$XSL_OUTPUT" > "$OUTPUT_FILE"
    [ "$STDOUT_OUTPUT" = "Y" ] && echo "$XSL_OUTPUT"
    ;;
  *)
    debug "UNMATCHED OUTPUT"
    OUTPUT="ERROR|UNEXPECTED_RESPONSE"
    echo "$OUTPUT" > "$OUTPUT_FILE"
    [ "$STDOUT_OUTPUT" = "Y" ] && echo "$OUTPUT"
    ;;
esac

exit 0

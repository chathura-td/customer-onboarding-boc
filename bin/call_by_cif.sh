#!/bin/bash
# ENTRY POINT 1: CIF -> Profile

ACCNO="$1"
BASE="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$BASE/../.env"
REQ="/tmp/req_${$}.xml"
RESP="/tmp/resp_${$}.xml"
LOGDIR="$BASE/../logs"
LOGFILE="$LOGDIR/api_$(date +%Y%m%d).log"

trap "rm -f $REQ $RESP" EXIT
mkdir -p "$LOGDIR"

# Load Environment Variables
if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
else
  echo "ERROR|ENV_FILE_MISSING"
  exit 1
fi

[ -z "$ACCNO" ] && { echo "ERROR|ACCNO_MISSING"; exit 1; }
UUID=$(uuidgen 2>/dev/null) || { echo "ERROR|UUIDGEN_FAILED"; exit 1; }

# Build request using .env variables and template from ../templates/
sed -e "s/{{UUID}}/$UUID/g" \
    -e "s/{{ACCNO}}/$ACCNO/g" \
    -e "s/{{API_USER}}/$API_USER/g" \
    -e "s/{{API_PASSWORD}}/$API_PASSWORD/g" \
    -e "s/{{CLIENT_APP_KEY}}/$CLIENT_APP_KEY/g" \
    "$BASE/../templates/request_cif.xml" > "$REQ"

# Call API using URL from .env
HTTP_CODE=$(curl -ks -o "$RESP" -w "%{http_code}" -H "Content-Type: application/xml" -X POST --data @"$REQ" "$API_URL")

echo "$(date '+%F %T') CIF=$ACCNO UUID=$UUID HTTP=$HTTP_CODE" >> "$LOGFILE"

[ "$HTTP_CODE" != "200" ] && { echo "ERROR|HTTP_$HTTP_CODE"; exit 1; }
xmllint --noout "$RESP" 2>/dev/null || { echo "ERROR|INVALID_XML"; exit 1; }

# Transform response using XSL from ../xsl/
XSL_OUTPUT=$(xsltproc "$BASE/../xsl/format_cif_response.xsl" "$RESP" | tr -d '\n')

case "$XSL_OUTPUT" in
  SUCCESS*|NOT_FOUND*|ERROR*) echo "$XSL_OUTPUT" ;;
  *) echo "ERROR|UNEXPECTED_RESPONSE" ;;
esac
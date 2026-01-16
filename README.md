# Customer Onboarding Utilities

Bash utility suite for querying customer information from the Bank of Ceylon CRG_PRODUAT IFX API endpoint. The scripts support account-to-customer mapping, customer profile lookups, and composite workflows with SSL certificate verification, comprehensive logging, and flexible output options.

## Features
- **Secure by default**: SSL certificate verification enabled with configurable certificates
- **Flexible output**: Write to files with optional stdout display
- **Debug logging**: Full request/response logging with daily rotation
- **Account type support**: Configurable account types (SV, CA, etc.)
- **Temp file cleanup**: Automatic cleanup of temporary request/response files
- **Error handling**: Structured error codes with HTTP and XML validation
- **Composite workflows**: Chain operations (account → CustPermId → profile)

## Project Structure
```
customer-onboarding-2/
├── scripts/                           # Executable bash scripts
│   ├── account_to_custid.sh          # Account number → CustPermId lookup
│   ├── customer_profile_lookup.sh    # CustPermId → Customer profile
│   └── customer_profile_by_account.sh # Account number → Customer profile (composite)
├── requests/                          # XML request templates
│   ├── account_to_custid_request.xml # AcctCustInqRq template ({{UUID}}, {{ACCTNO}}, {{ACCTTYPE}})
│   └── customer_profile_request.xml  # CustProfBasicInqRq template ({{UUID}}, {{ACCNO}})
├── xsl/                              # XSLT response formatters
│   ├── account_to_custid_formatter.xsl # Extract CustPermId from AcctCustInqRs
│   └── customer_profile_formatter.xsl  # Format CustProfBasicInqRs response
├── certificate/                       # SSL certificates
│   └── sample.crt                    # Default CA certificate for API endpoint
└── logs/                             # API activity logs (auto-created)
    └── api_YYYYMMDD.log              # Daily log files with timestamps
```

## Prerequisites
- **bash** (Bourne Again SHell)
- **curl** with SSL/TLS support
- **uuidgen** for generating unique request IDs
- **xmllint** (libxml2) for XML validation
- **xsltproc** (libxslt) for response transformation
- **Network access** to https://hofiservcom01.bankofceylon.local/CRG_PRODUAT/crg.aspx

## Scripts Overview

### 1. account_to_custid.sh
**Purpose**: Lookup Customer Permanent ID (CustPermId) from an account number.

**Usage**: `./scripts/account_to_custid.sh <ACCOUNT_NUMBER> [ACCT_TYPE]`

**Parameters**:
- `ACCOUNT_NUMBER` (required): Bank account number
- `ACCT_TYPE` (optional): Account type code (default: `SV`)
  - `SV` - Savings account
  - `CA` - Current account
  - Other types as supported by the API

**Output**: Printed to stdout
- Success: `CUSTID|<customer_permanent_id>`
- Error: `ERROR|<error_code>`

**Process**:
1. Validates input account number
2. Generates unique UUID for request tracking
3. Builds XML request from template with account number and type
4. Calls API with SSL verification (default) or insecure mode
5. Validates HTTP response (expects 200) and XML structure
6. Transforms response using XSLT to extract CustPermId
7. Returns formatted output

**Error Codes**:
- `ERROR|ACCTNO_MISSING` - Account number parameter not provided
- `ERROR|UUIDGEN_FAILED` - Unable to generate UUID
- `ERROR|HTTP_XXX` - HTTP error (non-200 response)
- `ERROR|INVALID_XML` - Response is not valid XML
- `ERROR|ACCT_LOOKUP_FAILED` - API returned non-zero status code
- `ERROR|NO_RELATION_FOUND` - No customer relation found for account
- `ERROR|CUSTID_NOT_FOUND` - Could not extract CustPermId from response

---

### 2. customer_profile_lookup.sh
**Purpose**: Fetch detailed customer profile information using Customer Permanent ID (CustPermId).

**Usage**: `./scripts/customer_profile_lookup.sh <CUST_PERM_ID>`

**Parameters**:
- `CUST_PERM_ID` (required): Customer Permanent ID obtained from account lookup

**Output**: Written to `/tmp/<CUST_PERM_ID>_profile.txt`
- Success: `SUCCESS|<branch_id>|<short_name>|<status_code>`
- Not Found: `NOT_FOUND|<error_number>|<error_description>`
- Error: `ERROR|<error_code>`

Optional stdout output controlled by `STDOUT_OUTPUT=Y` environment variable.

**Process**:
1. Validates input CustPermId
2. Generates unique UUID for request tracking
3. Builds XML request from template with CustPermId
4. Logs SSL verification status when DEBUG=Y
5. Calls API with certificate verification
6. Validates HTTP 200 response and XML structure
7. Transforms response using XSLT
8. Writes output to file (and optionally stdout)

**Error Codes**:
- `ERROR|ACCNO_MISSING` - CustPermId parameter not provided
- `ERROR|UUIDGEN_FAILED` - Unable to generate UUID
- `ERROR|HTTP_XXX` - HTTP error (non-200 response)
- `ERROR|INVALID_XML_RESPONSE` - Response is not valid XML
- `ERROR|UNEXPECTED_RESPONSE` - Response format not recognized
- `NOT_FOUND|<num>|<desc>` - Customer not found (business error from API)

**Output File Location**: `/tmp/<CUST_PERM_ID>_profile.txt`

---

### 3. customer_profile_by_account.sh
**Purpose**: End-to-end workflow to retrieve customer profile starting from an account number.

**Usage**: `./scripts/customer_profile_by_account.sh <ACCOUNT_NUMBER> [ACCT_TYPE]`

**Parameters**:
- `ACCOUNT_NUMBER` (required): Bank account number
- `ACCT_TYPE` (optional): Account type code (default: `SV`)

**Output**: Written to `/tmp/<CUST_PERM_ID>_profile.txt`
- Success: `SUCCESS|<branch_id>|<short_name>|<status_code>`
- Error: `ERROR|<error_code>` (from either step)

**Process**:
1. Calls `account_to_custid.sh` to get CustPermId from account number
2. If successful, extracts CustPermId from response
3. Calls `customer_profile_lookup.sh` with the CustPermId
4. Returns final profile information

This script chains the two operations and inherits all error codes from both underlying scripts. All environment variables affect the respective underlying scripts.

---

## Usage
From the project root:

```bash
# Lookup customer profile directly by CustPermId
./scripts/customer_profile_lookup.sh <CUST_PERM_ID>

# Lookup customer profile starting from account number
./scripts/customer_profile_by_account.sh <ACCOUNT_NUMBER> [ACCT_TYPE]

# Just fetch the CustPermId for an account
./scripts/account_to_custid.sh <ACCOUNT_NUMBER> [ACCT_TYPE]
```

ACCT_TYPE defaults to "SV" if not provided.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DEBUG` | `N` | Enable debug logging. Set to `Y` to log full request/response XML bodies, SSL status, and transformation output to daily log files |
| `STDOUT_OUTPUT` | `N` | Display output to terminal. Set to `Y` to echo results to stdout in addition to file output (applies to `customer_profile_lookup.sh` and composite script) |
| `SKIP_SSL_VERIFY` | `N` | Disable SSL certificate verification. Set to `Y` to skip certificate checks (insecure, for development only) |
| `CERT_FILE` | `certificate/sample.crt` | Path to CA certificate file for SSL verification. Override with custom certificate path |

**Notes**:
- All scripts automatically log API calls (timestamp, parameters, UUID, HTTP status) to `logs/api_YYYYMMDD.log`
- Debug logs include: SSL verification mode, full request XML, full response XML, XSLT transformation output
- Environment variables can be combined: `DEBUG=Y STDOUT_OUTPUT=Y ./scripts/customer_profile_lookup.sh 1234567890`

---

### Examples

#### Basic Operations

**1. Get CustPermId from account number**
```bash
# Using default account type (SV - Savings)
./scripts/account_to_custid.sh 1000012345

# Output: CUSTID|1234567890
```

**2. Specify account type**
```bash
# Current Account (CA)
./scripts/account_to_custid.sh 1000012345 CA

# Output: CUSTID|1234567890
```

**3. Lookup customer profile by CustPermId**
```bash
./scripts/customer_profile_lookup.sh 1234567890

# Output written to: /tmp/1234567890_profile.txt
# Content: SUCCESS|001|JOHN DOE|ACTIVE
```

**4. End-to-end: Account to Profile**
```bash
# Single command to get profile from account number
./scripts/customer_profile_by_account.sh 1000012345 SV

# Output written to: /tmp/<custpermid>_profile.txt
```

---

#### SSL Certificate Verification

**Default secure mode (SSL verification enabled)**
```bash
# Uses certificate/sample.crt by default
./scripts/customer_profile_lookup.sh 1234567890

# Verify in debug log:
# DEBUG: SSL: Verification ENABLED using certificate: /path/to/certificate/sample.crt
```

**Verify SSL is working with debug mode**
```bash
DEBUG=Y ./scripts/customer_profile_lookup.sh 1234567890
# Check logs/api_YYYYMMDD.log for:
# - "SSL: Verification ENABLED using certificate: ..."
# - Full request/response XML
```

**Use custom certificate**
```bash
CERT_FILE=/etc/ssl/certs/custom.crt ./scripts/customer_profile_lookup.sh 1234567890
```

**Development mode (skip SSL verification - NOT RECOMMENDED for production)**
```bash
SKIP_SSL_VERIFY=Y ./scripts/customer_profile_lookup.sh 1234567890
# Debug log will show: SSL: Verification DISABLED (insecure mode)
```

---

#### Output Control

**Display output to screen (default: file only)**
```bash
# See results in terminal AND write to file
STDOUT_OUTPUT=Y ./scripts/customer_profile_lookup.sh 1234567890
# Terminal output: SUCCESS|001|JOHN DOE|ACTIVE
# File output: /tmp/1234567890_profile.txt
```

**Silent mode (default) - output to file only**
```bash
./scripts/customer_profile_lookup.sh 1234567890
# No terminal output, check: cat /tmp/1234567890_profile.txt
```

---

#### Combined Environment Variables

**Full debugging with screen output**
```bash
DEBUG=Y STDOUT_OUTPUT=Y ./scripts/customer_profile_lookup.sh 1234567890
# Logs full XML to logs/api_YYYYMMDD.log
# Displays result on terminal
# Writes to /tmp/1234567890_profile.txt
```

**Development testing with custom certificate**
```bash
DEBUG=Y CERT_FILE=/path/to/test.crt ./scripts/account_to_custid.sh 1000012345
```

---

## Output Formats

### account_to_custid.sh
**Stdout output**:
- `CUSTID|<customer_permanent_id>` - Success
- `ERROR|<error_code>` - Failure

### customer_profile_lookup.sh
**File output** (`/tmp/<CUST_PERM_ID>_profile.txt`):
- `SUCCESS|<branch_id>|<short_name>|<status_code>` - Customer found
- `NOT_FOUND|<error_num>|<error_description>` - Customer not found (API business error)
- `ERROR|<error_code>` - Technical error

**Stdout output** (when `STDOUT_OUTPUT=Y`):
- Same format as file output

### customer_profile_by_account.sh
**File output** (`/tmp/<CUST_PERM_ID>_profile.txt`):
- Same as `customer_profile_lookup.sh`
- May return errors from either `account_to_custid.sh` or `customer_profile_lookup.sh`

---

## Logging

### Daily Activity Logs
Location: `logs/api_YYYYMMDD.log` (auto-created)

**Standard logging** (always enabled):
```
2026-01-16 14:32:45 ACCTNO=1000012345 ACCTTYPE=SV UUID=a1b2c3d4-... HTTP=200
2026-01-16 14:32:46 ACCNO=1234567890 UUID=e5f6g7h8-... HTTP=200
```

**Debug logging** (when `DEBUG=Y`):
```
2026-01-16 14:32:45 DEBUG: ACCNO=1234567890
2026-01-16 14:32:45 DEBUG: UUID=a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6
2026-01-16 14:32:45 DEBUG: REQUEST XML:
2026-01-16 14:32:45 DEBUG:   <IFX>
2026-01-16 14:32:45 DEBUG:     <SignonRq>...
2026-01-16 14:32:45 DEBUG: SSL: Verification ENABLED using certificate: /path/to/certificate/sample.crt
2026-01-16 14:32:46 DEBUG: RESPONSE XML:
2026-01-16 14:32:46 DEBUG:   <IFX>...
2026-01-16 14:32:46 DEBUG: XSL OUTPUT: SUCCESS|001|JOHN DOE|ACTIVE
```

### Temporary Files
- Request XML: `/tmp/req_<pid>.xml` or `/tmp/acct_req_<pid>.xml`
- Response XML: `/tmp/resp_<pid>.xml` or `/tmp/acct_resp_<pid>.xml`
- **Auto-cleanup**: Automatically removed on script exit (via trap)

---

## API Details

**Endpoint**: `https://hofiservcom01.bankofceylon.local/CRG_PRODUAT/crg.aspx`

**Authentication**: Embedded in XML request templates
- Username: `FTUSER`
- Password: `FT@uat01` (encrypted in transit via HTTPS)
- Client App Key: `BOCSRVRHECGNSYSQCUWRJDHKRFDBNTGN`

**Request Format**: IFX (Interactive Financial eXchange) XML
- Account lookup: `MaintSvcRq` > `AcctCustInqRq`
- Profile lookup: `CIFSvcRq` > `CustProfBasicInqRq`

**Response Processing**:
1. HTTP status validation (expects 200)
2. XML well-formedness validation (xmllint)
3. XSLT transformation to extract data
4. Business logic validation (status codes)

---

## Technical Implementation

### Request Flow
```
Input Parameters
    ↓
Generate UUID
    ↓
Build XML Request (sed substitution)
    ↓
[DEBUG: Log request XML]
    ↓
SSL Certificate Check
    ↓
HTTPS POST to API
    ↓
[DEBUG: Log SSL status]
    ↓
HTTP Response Validation
    ↓
XML Structure Validation
    ↓
[DEBUG: Log response XML]
    ↓
XSLT Transformation
    ↓
[DEBUG: Log transformed output]
    ↓
Output Formatting
    ↓
Write to File / Stdout
```

### Error Handling
- **Input validation**: Checks for required parameters
- **HTTP validation**: Ensures 200 OK response
- **XML validation**: Uses xmllint for structure verification
- **Business validation**: Checks API status codes in response
- **Graceful cleanup**: Trap ensures temp file removal on exit/error

### Security Features
- **SSL/TLS**: Certificate-based verification (default enabled)
- **Secure credentials**: Transmitted only over HTTPS
- **Temp file isolation**: Process-ID-based unique temp files
- **Auto-cleanup**: No sensitive data left in filesystem
- **Configurable security**: Can require certificate verification

---

## Troubleshooting

### Common Issues

**Issue**: `ERROR|UUIDGEN_FAILED`
- **Cause**: `uuidgen` command not found or failed
- **Solution**: Install uuid-runtime package: `apt-get install uuid-runtime` (Debian/Ubuntu) or `yum install util-linux` (RHEL/CentOS)

**Issue**: `ERROR|INVALID_XML` or `ERROR|INVALID_XML_RESPONSE`
- **Cause**: Response from API is not valid XML or xmllint not installed
- **Solution**: 
  - Install libxml2: `apt-get install libxml2-utils` or `yum install libxml2`
  - Enable debug mode to inspect raw response: `DEBUG=Y ./scripts/...`

**Issue**: `ERROR|HTTP_XXX` (non-200 response)
- **Cause**: API returned error HTTP status
- **Common codes**:
  - 401/403: Authentication/authorization failure
  - 404: Endpoint not found (check URL)
  - 500/503: Server error
- **Solution**: Check network connectivity, verify API endpoint is accessible, review credentials in XML templates

**Issue**: SSL certificate verification failures
- **Cause**: Certificate expired, invalid, or wrong certificate file
- **Solution**:
  - Verify certificate file exists and is readable: `ls -l certificate/sample.crt`
  - Check certificate validity: `openssl x509 -in certificate/sample.crt -text -noout`
  - Temporary workaround for development: `SKIP_SSL_VERIFY=Y`
  - Update certificate: Replace `certificate/sample.crt` or use `CERT_FILE=/path/to/new.crt`

**Issue**: No output or empty files
- **Cause**: Script executing but not producing expected output
- **Solution**:
  - Enable debug and stdout: `DEBUG=Y STDOUT_OUTPUT=Y ./scripts/customer_profile_lookup.sh 1234567890`
  - Check log file: `tail -100 logs/api_$(date +%Y%m%d).log`
  - Verify output file location: `ls -lh /tmp/*_profile.txt`

**Issue**: `ERROR|CUSTID_NOT_FOUND` or `ERROR|NO_RELATION_FOUND`
- **Cause**: Account number doesn't have associated customer or wrong account type
- **Solution**: 
  - Verify account number is correct
  - Try different account type: `./scripts/account_to_custid.sh 1000012345 CA`
  - Check if account exists in the system

**Issue**: Permission denied or command not found
- **Cause**: Scripts not executable or wrong path
- **Solution**: 
  - Make scripts executable: `chmod +x scripts/*.sh`
  - Run from project root with relative path: `./scripts/script_name.sh`

---

## Best Practices

### Production Use
1. **Always use SSL verification**: Never set `SKIP_SSL_VERIFY=Y` in production
2. **Rotate certificates**: Keep `certificate/sample.crt` updated with valid certificates
3. **Monitor logs**: Regularly review `logs/api_*.log` for errors and anomalies
4. **Secure credentials**: Restrict access to XML templates containing credentials (chmod 600)
5. **Output files**: Implement cleanup for `/tmp/*_profile.txt` files based on your retention policy

### Development & Testing
1. **Use DEBUG mode**: Enable `DEBUG=Y` to troubleshoot issues
2. **Verify SSL setup**: Test SSL verification before deploying
3. **Test error paths**: Validate error handling with invalid inputs
4. **Check output**: Use `STDOUT_OUTPUT=Y` during development for immediate feedback

### Integration
1. **Parse output**: Use pipe-delimited format for easy parsing in scripts
2. **Check exit codes**: Scripts return non-zero on errors
3. **Handle async**: Consider API response times in automation workflows
4. **Log correlation**: Use timestamps and UUIDs from logs for troubleshooting

---

## Maintenance

### Log Rotation
Logs are organized by date (`api_YYYYMMDD.log`). Implement cleanup as needed:
```bash
# Remove logs older than 30 days
find logs/ -name "api_*.log" -mtime +30 -delete
```

### Certificate Updates
Replace the certificate file when expired or changed:
```bash
# Backup old certificate
cp certificate/sample.crt certificate/sample.crt.bak

# Install new certificate
cp /path/to/new.crt certificate/sample.crt

# Verify
openssl x509 -in certificate/sample.crt -text -noout | grep "Not After"
```

### Credential Rotation
When API credentials change, update XML template files:
- `requests/account_to_custid_request.xml`
- `requests/customer_profile_request.xml`

Update the following fields:
- `<CustLoginId>` - Username
- `<Pswd>` - Password  
- `<ClientAppKey>` - Application key

---

## Notes
- **XML templates preserved**: Request body content unchanged from original implementation
- **Logic preserved**: All business logic, validations, and error handling unchanged
- **Reorganized structure**: Only file locations and names updated for better organization
- **Backward compatibility**: Exit codes and output formats maintained
- **Temp file management**: Scripts create process-specific files in `/tmp` and auto-cleanup on exit
- **Idempotent**: Safe to run multiple times with same parameters

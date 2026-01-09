
---

# Customer Onboarding API Integration

This project provides a two-step integration with the Bank of Ceylon IFX API to retrieve customer information. It supports looking up a profile directly via a **CIF (CustPermId)** or indirectly starting from an **Account Number**.

## Architecture & Directory Structure

The system is organized into a modular structure to separate logic, data templates, and transformation rules.

```text
customer-onboarding/
├── .env                        # Centralized credentials and API configuration
├── bin/                        # Executable logic
[cite_start]│   ├── call_by_account.sh      # ENTRY POINT: Resolves Account -> CIF -> Profile [cite: 19]
[cite_start]│   ├── call_by_cif.sh          # ENTRY POINT: Fetches Profile via CIF [cite: 12]
[cite_start]│   └── acct_to_custid.sh       # INTERNAL: Resolves Account to CIF [cite: 1]
├── templates/                  # XML request structures
[cite_start]│   ├── request_cif.xml         # Template for CIF profile inquiry [cite: 9]
[cite_start]│   └── request_acct_to_custid.xml # Template for Account lookup [cite: 24]
├── xsl/                        # Transformation logic
[cite_start]│   ├── format_cif_response.xsl # Parses profile XML into pipe-delimited text [cite: 7]
[cite_start]│   └── format_acct_to_custid.xsl # Parses Account XML into CUSTID|xxxx [cite: 23]
[cite_start]└── logs/                       # Daily execution logs [cite: 1, 12]

```

---

## RHEL Prerequisites

Ensure your RHEL environment has the necessary utilities installed to handle XML processing and network requests:

```bash
# Install required packages via DNF
sudo dnf install curl libxml2 libxslt util-linux

```

* 
**curl**: Performs the HTTPS POST requests to the API.


* 
**xmllint**: Validates that API responses are well-formed XML.


* 
**xsltproc**: Applies XSL transformations to extract specific data fields.


* 
**uuidgen**: Generates the required unique `RqUID` for every IFX request.



---

## Configuration (`.env`)

To avoid hardcoding sensitive information in templates, the scripts load variables from a `.env` file located in the project root.

**File: `.env**`

---

## Execution Guide

### 1. Lookup by Account Number

This is the most common use case. It automatically performs a two-step process: first calling `acct_to_custid.sh` and then `call_by_cif.sh`.

```bash
# Usage: ./bin/call_by_account.sh <ACCOUNT_NUMBER>
./bin/call_by_account.sh 123456789

```

### 2. Lookup by CIF (CustPermId)

Use this if the Customer ID is already known.

```bash
# Usage: ./bin/call_by_cif.sh <CIF_NUMBER>
./bin/call_by_cif.sh 9876543

```

---

## Error Handling & Troubleshooting

The scripts return standard pipe-delimited strings for easy consumption by upstream systems:

| Output | Meaning |
| --- | --- |
| `SUCCESS|...` | Profile retrieved successfully.

 |
| `CUSTID|xxxx` | Internal success resolving an account to a CIF.

 |
| `NOT_FOUND|...` | The API returned a business-level error (e.g., invalid ID).

 |
| `ERROR|HTTP_XXX` | Network or server-level failure (e.g., 404 or 500).

 |
| `ERROR|INVALID_XML` | The response from the bank was not valid XML.

 |

### Logging

All transactions are logged by date in `logs/api_YYYYMMDD.log`.
To enable detailed debug logging (including full XML request/response bodies), use the `DEBUG` flag:

```bash
DEBUG=Y ./bin/call_by_account.sh 123456789

```

---

## Security & Permissions

On RHEL, ensure the following permissions are set to protect credentials:

1. **Restrict .env**: `chmod 600 .env` (Only the owner can read/write).
2. **Scripts**: `chmod 755 bin/*.sh` (Allow execution).
3. 
**Logs**: Ensure the user running the scripts has write access to the `logs/` directory.
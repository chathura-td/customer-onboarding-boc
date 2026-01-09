# Customer Onboarding API Integration (RHEL)

This integration layer interacts with the Bank of Ceylon IFX API to retrieve customer profiles via Account Number or CIF.

## 📁 Structure
* **bin/**: Shell scripts (Entry points and internal logic).
* **templates/**: XML request templates with placeholders.
* **xsl/**: XSLT files for parsing XML responses.
* **logs/**: Automatically generated daily logs.

## 🚀 Usage
1. **By Account Number**: `./bin/call_by_account.sh <ACCOUNT_NUMBER>`
2. **By CIF (CustPermId)**: `./bin/call_by_cif.sh <CIF_NUMBER>`

## 🔐 Configuration
Credentials and URLs are managed in the `.env` file in the root directory.
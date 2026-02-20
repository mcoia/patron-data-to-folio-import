# Wichita State University
## Patron Data File Specification

**Parser:** WichitaParser
**File Format Supported:** CSV (.csv) only
**Last Updated:** January 2026
**Contact:** MOBIUS Consortium Office

---

## Overview

Wichita State uses a **direct column mapping format** with individual columns for each patron field. No Sierra zero-line encoding is used.

**Key Characteristics:**
- CSV format only (Excel NOT supported)
- Separate columns for name components (firstName, lastName, middleName)
- Separate columns for address components (address, city, state, zip)
- Date format conversion: YYYY-MM-DD → MM-DD-YY
- ESID comes directly from CSV `esid` column (no fallback)

---

## File Format Requirements

### Character Encoding
- **CSV Only:** UTF-8

### File Extension
- `.csv` files only
- Excel files (.xlsx) are NOT supported

### Structure
- **Row 1:** Column headers (case-sensitive)
- **Row 2+:** Patron data

---

## Column Headers

| Column Name | Required | Description | Format | Example |
|------------|----------|-------------|---------|---------|
| `lastName` | **Yes** | Patron last name | Text | `Smith` |
| `firstName` | **Yes** | Patron first name | Text | `John` |
| `middleName` | No | Patron middle name | Text | `Alan` or `A` |
| `address` | No | Street address | Text | `1845 Fairmount Street` |
| `city` | No | City | Text | `Wichita` |
| `state` | No | State abbreviation | 2-letter code | `KS` |
| `zip` | No | ZIP code | 5 or 9 digits | `67260` or `67260-0001` |
| `patronType` | No | Patron type designation | Text or number | `Student` or `10` |
| `expirationDate` | **Yes** | Patron expiration date | **YYYY-MM-DD** | `2026-05-17` |
| `phoneNumber` | No | Primary telephone | Numbers/dashes | `316-978-3456` |
| `username` | **Yes** | Unique username/ID | Alphanumeric | `w123456` |
| `barcode` | **Yes** | Patron barcode | Numeric | `87654321` |
| `emailAddress` | **Yes** | Email address | Valid email | `john.smith@wichita.edu` |
| `esid` | **Yes** | External System ID | Alphanumeric/email | `john.smith@wichita.edu` |

---

## Date Format Conversion (CRITICAL)

The parser **automatically converts** expiration dates from ISO format to Sierra format:

### Input Format (What YOU provide)
**YYYY-MM-DD** (ISO 8601 format)
- Example: `2026-05-17`
- Example: `2025-12-31`

### Output Format (What parser creates)
**MM-DD-YY** (Sierra format)
- Example: `05-17-26`
- Example: `12-31-25`

**Important:** You MUST provide dates in YYYY-MM-DD format in your CSV file. The parser will handle the conversion automatically.

---

## Name Assembly

Names are assembled into "Last, First Middle" format by the parser:

**Input:**
- `lastName`: `Smith`
- `firstName`: `John`
- `middleName`: `Alan`

**Output:**
- `name`: `Smith, John Alan`

**Without middle name:**
- Input: `lastName=Doe`, `firstName=Jane`, `middleName=` (empty)
- Output: `Doe, Jane`

---

## Address Assembly

Address components are combined into a single address field:

**Input:**
- `address`: `1845 Fairmount Street`
- `city`: `Wichita`
- `state`: `KS`
- `zip`: `67260`

**Output:**
- `address`: `1845 Fairmount Street Wichita KS 67260`

All non-empty components are joined with spaces.

---

## ESID Handling

**CRITICAL:** Wichita parser uses ESID **directly from CSV only** - there is NO fallback to ESID builder.

- ESID value comes from the `esid` column
- If `esid` column is empty, patron will be REJECTED
- Ensure every row has a non-empty `esid` value

---

## Sample Data File

### CSV Format Example

```csv
lastName,firstName,middleName,address,city,state,zip,patronType,expirationDate,phoneNumber,username,barcode,emailAddress,esid
Smith,John,Alan,1845 Fairmount Street,Wichita,KS,67260,Student,2026-05-17,316-978-3456,w123456,87654321,john.smith@wichita.edu,john.smith@wichita.edu
Doe,Jane,Marie,2100 Hillside Ave,Wichita,KS,67214,Faculty,2026-12-31,316-978-7890,w234567,98765432,jane.doe@wichita.edu,jane.doe@wichita.edu
Johnson,Robert,,3250 Oliver St,Wichita,KS,67220,Staff,2025-06-30,316-555-1234,w345678,11223344,robert.johnson@wichita.edu,rjohnson
Martinez,Maria,Elena,4567 E 21st St,Wichita,KS,67208,Student,2027-01-15,,w456789,22334455,maria.martinez@wichita.edu,maria.martinez@wichita.edu
```

### Detailed Row Example

**Input for Jane Doe:**
```
lastName: Doe
firstName: Jane
middleName: Marie
address: 2100 Hillside Ave
city: Wichita
state: KS
zip: 67214
patronType: Faculty
expirationDate: 2026-12-31
phoneNumber: 316-978-7890
username: w234567
barcode: 98765432
emailAddress: jane.doe@wichita.edu
esid: jane.doe@wichita.edu
```

**Processed patron data:**
- **Name:** `Doe, Jane Marie` (assembled from components)
- **Address:** `2100 Hillside Ave Wichita KS 67214` (assembled from components)
- **Telephone:** `316-978-7890`
- **Expiration Date:** `12-31-26` (converted from 2026-12-31)
- **Unique ID:** `w234567`
- **Barcode:** `98765432`
- **Email:** `jane.doe@wichita.edu`
- **ESID:** `jane.doe@wichita.edu` (from CSV)

---

## Field Normalization

The parser automatically normalizes fields by trimming whitespace:

### Name Components
- Leading and trailing spaces removed from lastName, firstName, middleName
- Empty middle names handled gracefully

### Address Components
- Whitespace trimmed from address, city, state, zip
- Empty placeholders or strings like "NULL" should be left as empty cells

### Other Fields
- patronType: trimmed
- phoneNumber: trimmed
- username: trimmed
- barcode: trimmed
- emailAddress: trimmed

---

## Validation Checklist

### Required Fields
- ☑ Every row has `lastName` and `firstName`
- ☑ Every row has `expirationDate` in YYYY-MM-DD format
- ☑ Every row has `username`
- ☑ Every row has `barcode`
- ☑ Every row has `emailAddress`
- ☑ Every row has `esid` (CRITICAL - no fallback)

### Format Validation
- ☑ Date format is YYYY-MM-DD (e.g., 2026-05-17)
- ☑ State codes are 2 letters (e.g., KS)
- ☑ Email addresses are valid format
- ☑ CSV file is UTF-8 encoded

### Data Quality
- ☑ No duplicate barcodes
- ☑ No duplicate usernames
- ☑ No duplicate ESIDs
- ☑ All names have both first and last
- ☑ Expiration dates are in the future (or intended date)

---

## Common Errors

### "ESID is empty"
**Cause:** The `esid` column is empty for one or more patrons
**Fix:** Populate `esid` column for EVERY patron - this field is required with no fallback

### "Invalid date format"
**Cause:** Expiration date not in YYYY-MM-DD format
**Fix:** Use YYYY-MM-DD format: `2026-05-17` NOT `05/17/2026` or `05-17-26`

### "Missing name components"
**Cause:** Empty lastName or firstName fields
**Fix:** Ensure both lastName and firstName are populated for every patron

### "Duplicate barcode"
**Cause:** Same barcode used for multiple patrons
**Fix:** Ensure every patron has a unique barcode

---

## File Preparation Tips

### Date Format
Use Excel or spreadsheet software to format dates as YYYY-MM-DD:
1. Format cells as "Custom" with format: `yyyy-mm-dd`
2. Or use TEXT formula: `=TEXT(A1,"yyyy-mm-dd")`

### ESID Values
ESID typically matches email address but can be any unique identifier:
- Email format: `john.smith@wichita.edu` ✓
- Username format: `w123456` ✓
- Student ID format: `123456789` ✓

Choose one consistent format for all patrons.

### Empty Fields
For optional empty fields, leave CSV cell empty:
- ✓ Correct: `,,` (empty cell)
- ✓ Correct: `""` (empty quoted string)
- ❌ Incorrect: `NULL` (literal text)
- ❌ Incorrect: `N/A` (literal text)

---

## File Submission

1. Save as `.csv` format (Excel NOT supported for this parser)
2. Ensure UTF-8 encoding
3. Verify all dates are YYYY-MM-DD format
4. Verify every row has `esid` value
5. Name file: `YYYY-MM-DD-Wichita-Patrons.csv`
6. Submit via MOBIUS secure file transfer
7. Include patron count in submission email

---

## Support

**MOBIUS Consortium Office**
Email: support@mobiusconsortium.org
Website: https://mobiusconsortium.org

---

**Document Version:** 1.0
**Parser Version:** WichitaParser.pm (2025-01)

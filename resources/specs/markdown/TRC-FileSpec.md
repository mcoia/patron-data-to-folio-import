# Three Rivers College
## Patron Data File Specification

**Parser:** TRCParser
**File Format Supported:** CSV (.csv) only
**Last Updated:** January 2026
**Contact:** MOBIUS Consortium Office

---

## Overview

Three Rivers College uses a **hybrid CSV format** with a special `text` field containing packed PCODE data. This combines direct column mapping with encoded Sierra-style metadata.

**Key Characteristics:**
- CSV format only (Excel NOT supported)
- Special `text` field contains packed PCODE/library data (11 characters)
- Separate columns for name components
- Patron type leading zeros automatically stripped
- ESID from CSV `esid` column with ESID builder fallback

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
| `firstName` | **Yes** | Patron first name | Text | `Jane` |
| `middleName` | No | Patron middle name | Text | `Marie` |
| `address` | No | Primary street address | Text | `2080 Three Rivers Blvd` |
| `cityStateZip` | No | City, state, and ZIP combined | Text | `Poplar Bluff, MO 63901` |
| `patronType` | **Yes** | Patron type (with leading zeros) | 3 digits | `007` or `045` |
| `expirationDate` | No | Patron expiration date | mm/dd/yyyy or mm-dd-yy | `05/17/2026` |
| `username` | **Yes** | Unique username/ID | Alphanumeric | `trc123456` |
| `barcode` | **Yes** | Patron barcode | Numeric | `87654321` |
| `emailAddress` | **Yes** | Email address | Valid email | `jane.smith@trcc.edu` |
| `text` | **Yes** | **PCODE field** (11 chars) | See format below | `l-000trcol ` |
| `esid` | No | External System ID (optional) | Alphanumeric | `jane.smith@trcc.edu` |

---

## CRITICAL: The `text` Field Format

The `text` field is a **special 11-character encoded field** that contains patron PCODE data and home library information.

### Format Structure (11 Characters)

```
Position 0:     PCODE1 (1 character)
Position 1:     PCODE2 (1 character)
Positions 2-4:  PCODE3 (3 characters)
Positions 5-9:  Home Library (5 characters)
Position 10:    Optional space or data
```

### Example `text` Values

```
l-000trcol     (PCODE1='l', PCODE2='-', PCODE3='000', library='trcol')
--003trlib     (PCODE1='-', PCODE2='-', PCODE3='003', library='trlib')
ab025threR     (PCODE1='a', PCODE2='b', PCODE3='025', library='threR')
```

### Position-by-Position Breakdown

**Example:** `l-000trcol `

| Positions | Value | Field | Meaning |
|-----------|-------|-------|---------|
| 0 | `l` | PCODE1 | Statistical code 1 |
| 1 | `-` | PCODE2 | Statistical code 2 (hyphen = not defined) |
| 2-4 | `000` | PCODE3 | Statistical code 3 |
| 5-9 | `trcol` | Home Library | "trcol" (5 characters) |
| 10 | ` ` | Extra | Space padding (optional) |

**IMPORTANT:** The `text` field MUST be at least 10 characters long (positions 0-9). Position 10 is optional.

---

## Patron Type Leading Zero Stripping

The parser automatically strips leading zeros from patron types:

**Input → Output:**
- `007` → `7`
- `045` → `45`
- `012` → `12`
- `100` → `100` (no leading zeros)

This conversion happens automatically - you provide patron type with leading zeros (for consistency), and the parser converts to numbers.

---

## Name Assembly

Names are assembled into "Last, First Middle" format:

**Input:**
- `lastName`: `Smith`
- `firstName`: `Jane`
- `middleName`: `Marie`

**Output:**
- `name`: `Smith, Jane Marie`

---

## ESID Handling

ESID (External System ID) uses the following logic:

1. **If `esid` column is populated:** Uses that value
2. **If `esid` column is empty:** Uses ESID builder fallback (generates from available patron data)

Unlike Wichita parser, TRC has a fallback mechanism.

---

## Sample Data File

### CSV Format Example

```csv
lastName,firstName,middleName,address,cityStateZip,patronType,expirationDate,username,barcode,emailAddress,text,esid
Smith,Jane,Marie,2080 Three Rivers Blvd,"Poplar Bluff, MO 63901",007,05/17/2026,trc123456,87654321,jane.smith@trcc.edu,l-000trcol,jane.smith@trcc.edu
Doe,John,Alan,1234 Main Street,"Poplar Bluff, MO 63901",045,12/31/2025,trc234567,98765432,john.doe@trcc.edu,--003trlib,john.doe@trcc.edu
Johnson,Maria,,5678 Highway 67,"Poplar Bluff, MO 63901",012,06/30/2026,trc345678,11223344,maria.johnson@trcc.edu,ab025threR,maria.johnson@trcc.edu
Williams,Robert,Lee,9012 Oak Street,"Sikeston, MO 63801",007,08/15/2026,trc456789,22334455,robert.williams@trcc.edu,l-000trcol,robert.williams@trcc.edu
```

### Detailed Row Example

**Input for Jane Smith:**
```
lastName: Smith
firstName: Jane
middleName: Marie
address: 2080 Three Rivers Blvd
cityStateZip: Poplar Bluff, MO 63901
patronType: 007
expirationDate: 05/17/2026
username: trc123456
barcode: 87654321
emailAddress: jane.smith@trcc.edu
text: l-000trcol
esid: jane.smith@trcc.edu
```

**Processed patron data:**
- **Name:** `Smith, Jane Marie`
- **Address:** `2080 Three Rivers Blvd`
- **Address2:** `Poplar Bluff, MO 63901`
- **Patron Type:** `7` (leading zeros stripped from 007)
- **PCODE1:** `l` (from text[0])
- **PCODE2:** `-` (from text[1])
- **PCODE3:** `000` (from text[2-4])
- **Home Library:** `trcol` (from text[5-9])
- **Expiration Date:** `05/17/2026`
- **Unique ID:** `trc123456`
- **Barcode:** `87654321`
- **Email:** `jane.smith@trcc.edu`
- **ESID:** `jane.smith@trcc.edu`

---

## Field Extraction from `text`

### PCODE1 Extraction
```
text = "l-000trcol"
PCODE1 = text[0] = "l"
```

### PCODE2 Extraction
```
text = "l-000trcol"
PCODE2 = text[1] = "-"
```

### PCODE3 Extraction
```
text = "l-000trcol"
PCODE3 = text[2-4] = "000"
```

### Home Library Extraction
```
text = "l-000trcol"
Home Library = text[5-9] = "trcol"
```

---

## Validation Checklist

### Required Fields
- ☑ Every row has `lastName` and `firstName`
- ☑ Every row has `patronType` (3 digits with leading zeros)
- ☑ Every row has `username`
- ☑ Every row has `barcode`
- ☑ Every row has `emailAddress`
- ☑ Every row has `text` field (at least 10 characters)

### `text` Field Validation
- ☑ `text` field is at least 10 characters long
- ☑ Positions 0-1 contain PCODE1 and PCODE2 characters
- ☑ Positions 2-4 contain 3-character PCODE3 (can include zeros)
- ☑ Positions 5-9 contain 5-character home library code
- ☑ If library code is less than 5 characters, it should be right-padded with spaces

### Format Validation
- ☑ patronType is 3 digits (e.g., 007, 045, 100)
- ☑ Email addresses are valid format
- ☑ CSV file is UTF-8 encoded

### Data Quality
- ☑ No duplicate barcodes
- ☑ No duplicate usernames
- ☑ All names have both first and last
- ☑ text field properly formatted for all rows

---

## Common Errors

### "text field too short"
**Cause:** `text` field has fewer than 10 characters
**Fix:** Ensure `text` is at least 10 characters: 1+1+3+5 = 10 chars minimum

### "Invalid patronType"
**Cause:** patronType is not 3 digits
**Fix:** Use 3 digits with leading zeros: `007`, `045` not `7`, `45`

### "Missing text field"
**Cause:** `text` column is empty
**Fix:** Every patron must have a properly formatted `text` field

### "Invalid library code"
**Cause:** Home library in text field is not 5 characters
**Fix:** Pad library code to 5 characters with spaces if needed:
- `trc` → `trc  ` (trc + 2 spaces)
- `trlib` → `trlib` (exactly 5 chars)

---

## File Preparation Tips

### Creating the `text` Field

**Template:**
```
[P1][P2][PC3][LIBRARY]

Where:
P1 = PCODE1 (1 character)
P2 = PCODE2 (1 character)
PC3 = PCODE3 (3 characters, can include zeros)
LIBRARY = 5-character library code (pad with spaces if needed)
```

**Examples:**
- PCODE1=`l`, PCODE2=`-`, PCODE3=`000`, Library=`trcol`
  → `l-000trcol`

- PCODE1=`-`, PCODE2=`-`, PCODE3=`003`, Library=`trlib`
  → `--003trlib`

- PCODE1=`a`, PCODE2=`b`, PCODE3=`025`, Library=`trc`
  → `ab025trc  ` (note: trc + 2 spaces = 5 chars)

### Patron Type Formatting
Always use 3 digits with leading zeros:
- Type 7 → `007`
- Type 45 → `045`
- Type 100 → `100`

### Home Library Codes
Common Three Rivers library codes (pad to 5 characters):
- `trcol` (5 chars - no padding needed)
- `trlib` (5 chars - no padding needed)
- `trc` → `trc  ` (add 2 spaces)
- `three` (5 chars - no padding needed)

---

## File Submission

1. Save as `.csv` format (Excel NOT supported)
2. Ensure UTF-8 encoding
3. Verify all `text` fields are at least 10 characters
4. Verify all patronType values are 3 digits
5. Name file: `YYYY-MM-DD-TRC-Patrons.csv`
6. Submit via MOBIUS secure file transfer
7. Include patron count in submission email

---

## Support

**MOBIUS Consortium Office**
Email: support@mobiusconsortium.org
Website: https://mobiusconsortium.org

---

**Document Version:** 1.0
**Parser Version:** TRCParser.pm (2025-01)

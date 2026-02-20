# State Technical College of Missouri
## Patron Data File Specification

**Parser:** StateTechParser
**File Formats Supported:** Excel (.xlsx) or CSV (.csv)
**Last Updated:** January 2026
**Contact:** MOBIUS Consortium Office

---

## Overview

This document describes the exact file format required for automated patron data loads for State Technical College of Missouri (State Tech). The parser supports both Microsoft Excel (.xlsx) and CSV (.csv) formats.

**Key Characteristics:**
- Uses Sierra-style "zero line" format for patron metadata
- Supports hybrid format with extended date (mm/dd/yyyy)
- Handles both Excel and CSV files automatically
- Sanitizes "NULL" string values to empty fields

---

## File Format Requirements

### Character Encoding
- **Excel Files:** UTF-8 (automatic)
- **CSV Files:** UTF-8 with or without BOM

### File Extension
- `.xlsx` for Excel files
- `.csv` for CSV files

### Structure
- **Row 1:** Column headers (see below)
- **Row 2+:** Patron data

---

## Column Headers

The following columns are expected in your data file. Column names are **case-sensitive** and must match exactly.

| Column Name | Required | Description | Example |
|------------|----------|-------------|---------|
| `fullname` | **Yes** | Full patron name in "Last, First Middle" format | `Smith, John A` |
| `PTYPE & Expiration` | **Yes** | Sierra zero-line format (see detailed section below) | `0061l-000lsb  --05/17/2026` |
| `address` | No | Street address; use `$` to separate street from city/state/zip | `123 Main St$Springfield, MO 65801` |
| `mobilephone` | No | Primary telephone number | `5731234567` or `573-123-4567` |
| `username` | No | Username/login (preferred for unique_id) | `00169523STC` |
| `uniqueid` | No | Alternative unique identifier (fallback if username empty) | `169523` |
| `Barcode` | No | Patron barcode (preferred field name) | `169523` |
| `Student ID Barcode Number` | No | Alternative barcode field (fallback if Barcode empty) | `169523` |
| `emailaddress` | No | Email address | `john.smith@iam.statetechmo.edu` |
| `externalID` | No | External system ID (ESID) | `John.Smith@iam.statetechmo.edu` |

### Field Priority/Fallbacks

The parser uses the following fallback logic when multiple columns provide similar data:

1. **Unique ID:** `username` → `uniqueid` → `emailaddress` (first non-empty value used)
2. **Barcode:** `Barcode` → `Student ID Barcode Number` (first non-empty value used)
3. **Zero Line:** `PTYPE & Expiration` → `Expiration Date` (first non-empty value used)

---

## Zero Line Format (CRITICAL)

The `PTYPE & Expiration` column contains encoded patron metadata in Sierra zero-line format. This is the **most important** field to format correctly.

### Format Structure

State Tech uses a **hybrid** format that follows standard Sierra positions 0-15 but supports extended date formats:

```
Position 0:       '0' (field code - REQUIRED)
Positions 1-3:    Patron Type (3 digits, e.g., 061)
Position 4:       PCODE1 (1 character)
Position 5:       PCODE2 (1 character)
Positions 6-8:    PCODE3 (3 characters)
Positions 9-13:   Home Library (5 characters, pad with spaces)
Position 14:      Patron Message Code (1 character)
Position 15:      Patron Block Code (1 character)
Position 16+:     Expiration Date (flexible format)
```

### Example Zero Lines

```
0061l-000lsb  --05/17/2026
0067l-003btg  --12/31/2025
0001--001shb  --06-15-26
```

### Position-by-Position Breakdown

**Example:** `0061l-000lsb  --05/17/2026`

| Positions | Value | Field | Meaning |
|-----------|-------|-------|---------|
| 0 | `0` | Field Code | Always '0' to indicate zero line |
| 1-3 | `061` | Patron Type | Patron type 61 (leading zeros stripped) |
| 4 | `l` | PCODE1 | Statistical code 1 |
| 5 | `-` | PCODE2 | Statistical code 2 (hyphen = undefined) |
| 6-8 | `000` | PCODE3 | Statistical code 3 |
| 9-13 | `lsb  ` | Home Library | "lsb" + 2 spaces = 5 characters |
| 14 | `-` | Patron Message Code | Hyphen = no message code |
| 15 | `-` | Patron Block Code | Hyphen = no block |
| 16+ | `05/17/2026` | Expiration Date | Patron expires May 17, 2026 |

### Supported Date Formats

The expiration date can be in any of these formats:
- `mm/dd/yyyy` (e.g., `05/17/2026`)
- `mm-dd-yy` (e.g., `05-17-26`)
- `mm.dd.yyyy` (e.g., `05.17.2026`)

---

## Special Field Formatting

### Name Format
Names must be in "Last, First Middle" format:
- ✅ Correct: `Smith, John A`
- ✅ Correct: `Doe, Jane Marie`
- ❌ Incorrect: `John Smith`
- ❌ Incorrect: `Smith John`

### Address Format
Addresses can use a `$` delimiter to separate street from city/state/zip:
- With delimiter: `123 Main St$Springfield, MO 65801`
- Without delimiter: `123 Main St Springfield MO 65801`

If using the delimiter:
- **Before `$`:** Street address → saved as `address`
- **After `$`:** City, state, zip → saved as `address2`

### NULL String Handling
The parser automatically converts literal "NULL" strings to empty values:
- If a field contains the text `NULL` or `null`, it will be treated as empty
- This prevents text "NULL" from appearing in patron records

---

## Sample Data File

### Excel Format Example

| fullname | PTYPE & Expiration | address | mobilephone | username | Barcode | emailaddress | externalID |
|----------|-------------------|---------|-------------|----------|---------|--------------|------------|
| Abel, Nicholas D | 0061l-000lsb  --05/17/2026 | 204 N Reserve St$Rosebud, MO 63091 | 5737894174 | 00169523STC | 169523 | Nicholas.Abel@iam.statetechmo.edu | Nicholas.Abel@iam.statetechmo.edu |
| Smith, Jane M | 0061l-000lsb  --05/17/2026 | 456 Oak Ave$Linn, MO 65051 | 5739876543 | 00234567STC | 234567 | Jane.Smith@iam.statetechmo.edu | Jane.Smith@iam.statetechmo.edu |
| Johnson, Robert | 0067l-003btg  --12/31/2025 | 789 Elm St$Jefferson City, MO 65101 | NULL | 00345678STC | 345678 | Robert.Johnson@iam.statetechmo.edu | Robert.Johnson@iam.statetechmo.edu |

### CSV Format Example

```csv
fullname,PTYPE & Expiration,address,mobilephone,username,Barcode,emailaddress,externalID
"Abel, Nicholas D",0061l-000lsb  --05/17/2026,"204 N Reserve St$Rosebud, MO 63091",5737894174,00169523STC,169523,Nicholas.Abel@iam.statetechmo.edu,Nicholas.Abel@iam.statetechmo.edu
"Smith, Jane M",0061l-000lsb  --05/17/2026,"456 Oak Ave$Linn, MO 65051",5739876543,00234567STC,234567,Jane.Smith@iam.statetechmo.edu,Jane.Smith@iam.statetechmo.edu
"Johnson, Robert",0067l-003btg  --12/31/2025,"789 Elm St$Jefferson City, MO 65101",NULL,00345678STC,345678,Robert.Johnson@iam.statetechmo.edu,Robert.Johnson@iam.statetechmo.edu
```

---

## Validation Checklist

Before submitting your patron file, verify:

### Required Fields
- ☑ Every row has a `fullname` in "Last, First Middle" format
- ☑ Every row has `PTYPE & Expiration` field starting with '0'
- ☑ Zero line is properly formatted (see format section)
- ☑ At least one identifier field is populated (username, uniqueid, or emailaddress)

### Format Validation
- ☑ Zero line starts with '0' character
- ☑ Zero line patron type is 3 digits (positions 1-3)
- ☑ Zero line home library is exactly 5 characters (positions 9-13)
- ☑ Expiration date is in supported format (mm/dd/yyyy, mm-dd-yy, or mm.dd.yyyy)
- ☑ Names use comma separator: "Last, First Middle"
- ☑ Excel file is .xlsx format (not .xls)
- ☑ CSV file is UTF-8 encoded

### Data Quality
- ☑ No actual "NULL" text in fields (use empty cells instead)
- ☑ Phone numbers contain only digits and optional dashes/parentheses
- ☑ Email addresses are valid format
- ☑ Barcodes are unique across all patrons
- ☑ No duplicate patron records

---

## Common Errors

### Error: "Zero line does not start with '0'"
**Cause:** The `PTYPE & Expiration` field doesn't begin with the digit 0
**Fix:** Ensure field starts with '0' character: `0061l-000...` not `061l-000...`

### Error: "Invalid name format"
**Cause:** Name not in "Last, First Middle" format
**Fix:** Use comma separator: `Smith, John` not `John Smith`

### Error: "NULL values in required fields"
**Cause:** Empty cells where data is required
**Fix:** Ensure fullname and PTYPE & Expiration are filled for all rows

### Error: "Invalid zero line length"
**Cause:** Zero line too short (missing positions)
**Fix:** Ensure positions 0-15 are present, pad home library to 5 chars

### Error: "No ESID generated"
**Cause:** All identifier fields (username, uniqueid, emailaddress, externalID) are empty
**Fix:** Populate at least one identifier field for each patron

---

## File Submission

Once your file is prepared and validated:

1. Save as `.xlsx` (Excel) or `.csv` (CSV) format
2. Name file descriptively: `YYYYMMDD-StateTech-Patron-Load.xlsx`
3. Submit via MOBIUS secure file transfer (contact MOBIUS Consortium Office)
4. Include patron count in your submission email

---

## Technical Notes

- Parser automatically detects file type based on extension
- Excel files: reads first worksheet only
- Duplicate detection uses fingerprint of all patron data
- ESID (External System ID) uses fallback: externalID → email → username
- Post-processing handles standard FOLIO field mapping

---

## Support

For questions or assistance with file preparation:

**MOBIUS Consortium Office**
Email: support@mobiusconsortium.org
Website: https://mobiusconsortium.org

---

**Document Version:** 1.0
**Parser Version:** StateTechParser.pm (2025-01)

# Stephens College
## Patron Data File Specification

**Parser:** StephensParser
**File Formats Supported:** Excel (.xlsx) or CSV (.csv)
**Last Updated:** January 2026
**Contact:** MOBIUS Consortium Office

---

## Overview

This document describes the file format required for automated patron data loads for Stephens College. The parser supports both Microsoft Excel (.xlsx) and CSV (.csv) formats with Sierra-style zero line encoding.

**Key Characteristics:**
- Uses Sierra-style "zero line" format for patron metadata
- Handles XML entity encoding in headers (`&amp;` → `&`)
- Supports both Excel and CSV files automatically
- Similar format to State Tech but with different column names

---

## File Format Requirements

### Character Encoding
- **Excel Files:** UTF-8 (automatic)
- **CSV Files:** UTF-8 with or without BOM

### File Extension
- `.xlsx` for Excel files
- `.csv` for CSV files

### Structure
- **Row 1:** Column headers (exact spelling required)
- **Row 2+:** Patron data

---

## Column Headers

| Column Name | Required | Description | Example |
|------------|----------|-------------|---------|
| `fullname` | **Yes** | Full name in "Last, First Middle" format | `Smith, Jane Marie` |
| `PTYPE & Expiration`<br>or `PTYPE &amp; Expiration` | **Yes** | Sierra zero-line format (parser handles both) | `0067l-003btg  --05/17/2026` |
| `address` | No | Street address; use `$` to separate street from city/state/zip | `100 E Broadway$Columbia, MO 65201` |
| `mobilephone` | No | Primary telephone number | `5731234567` |
| `uniqueid` | No | Unique identifier (preferred) | `12345678` |
| `emailaddress` | No | Email address (fallback for uniqueid) | `jane.smith@stephens.edu` |
| `Barcode` | No | Patron barcode | `12345678` |
| `externalID` | No | External system ID (ESID) | `jane.smith@stephens.edu` |

### Field Priority/Fallbacks

1. **Unique ID:** `uniqueid` → `emailaddress` (first non-empty value used)
2. **Zero Line:** `PTYPE & Expiration` → `PTYPE &amp; Expiration` (handles XML entity encoding)

---

## Zero Line Format

The `PTYPE & Expiration` column contains encoded patron metadata in standard Sierra zero-line format.

### Format Structure

```
Position 0:       '0' (field code - REQUIRED)
Positions 1-3:    Patron Type (3 digits)
Position 4:       PCODE1 (1 character)
Position 5:       PCODE2 (1 character)
Positions 6-8:    PCODE3 (3 characters)
Positions 9-13:   Home Library (5 characters, pad with spaces)
Position 14:      Patron Message Code (1 character)
Position 15:      Patron Block Code (1 character)
Position 16+:     Expiration Date (mm/dd/yyyy, mm-dd-yy, or mm.dd.yyyy)
```

### Example Zero Lines

```
0067l-003btg  --05/17/2026
0001--001sch  --12-31-25
0045c-002sph  --06.15.2026
```

### Position-by-Position Breakdown

**Example:** `0067l-003btg  --05/17/2026`

| Positions | Value | Field | Meaning |
|-----------|-------|-------|---------|
| 0 | `0` | Field Code | Always '0' |
| 1-3 | `067` | Patron Type | Type 67 |
| 4 | `l` | PCODE1 | Statistical code 1 |
| 5 | `-` | PCODE2 | Not defined |
| 6-8 | `003` | PCODE3 | Statistical code 3 |
| 9-13 | `btg  ` | Home Library | "btg" + 2 spaces |
| 14 | ` ` | Message Code | Space = none |
| 15 | `-` | Block Code | Hyphen = none |
| 16+ | `05/17/2026` | Expiration | May 17, 2026 |

---

## Sample Data File

### Excel Format Example

| fullname | PTYPE & Expiration | address | mobilephone | uniqueid | Barcode | emailaddress | externalID |
|----------|-------------------|---------|-------------|----------|---------|--------------|------------|
| Anderson, Mary K | 0067l-003btg  --05/17/2026 | 1200 E Broadway$Columbia, MO 65215 | 5731234567 | 87654321 | 87654321 | mary.anderson@stephens.edu | mary.anderson@stephens.edu |
| Brown, Sarah J | 0067l-003btg  --12/31/2025 | 456 Maple St$Columbia, MO 65201 | 5739876543 | 98765432 | 98765432 | sarah.brown@stephens.edu | sarah.brown@stephens.edu |
| Davis, Emily R | 0045c-002sph  --06/15/2026 | 789 Oak Ave$Columbia, MO 65203 | 5735551234 | 12348765 | 12348765 | emily.davis@stephens.edu | emily.davis@stephens.edu |

### CSV Format Example

```csv
fullname,PTYPE & Expiration,address,mobilephone,uniqueid,Barcode,emailaddress,externalID
"Anderson, Mary K",0067l-003btg  --05/17/2026,"1200 E Broadway$Columbia, MO 65215",5731234567,87654321,87654321,mary.anderson@stephens.edu,mary.anderson@stephens.edu
"Brown, Sarah J",0067l-003btg  --12/31/2025,"456 Maple St$Columbia, MO 65201",5739876543,98765432,98765432,sarah.brown@stephens.edu,sarah.brown@stephens.edu
"Davis, Emily R",0045c-002sph  --06/15/2026,"789 Oak Ave$Columbia, MO 65203",5735551234,12348765,12348765,emily.davis@stephens.edu,emily.davis@stephens.edu
```

---

## Special Field Formatting

### Name Format
Names must be in "Last, First Middle" format:
- ✅ Correct: `Anderson, Mary K`
- ✅ Correct: `Brown, Sarah Jane`
- ❌ Incorrect: `Mary Anderson`

### Address Format
Use `$` delimiter to separate street from city/state/zip:
- `1200 E Broadway$Columbia, MO 65215`
- Street goes to `address`, city/state/zip goes to `address2`

### XML Entity Handling
The parser automatically handles XML entity encoding in column headers:
- `PTYPE &amp; Expiration` is treated same as `PTYPE & Expiration`
- You can use either format in your file

---

## Validation Checklist

Before submitting your patron file:

### Required Fields
- ☑ Every row has `fullname` in "Last, First Middle" format
- ☑ Every row has `PTYPE & Expiration` starting with '0'
- ☑ At least one identifier (uniqueid or emailaddress) is populated

### Format Validation
- ☑ Zero line starts with '0' character
- ☑ Zero line is properly formatted (see format section)
- ☑ Names use comma separator
- ☑ Excel file is .xlsx format (not .xls)
- ☑ CSV file is UTF-8 encoded

### Data Quality
- ☑ No duplicate patron records
- ☑ Email addresses are valid format
- ☑ Barcodes are unique across all patrons

---

## Common Errors

### "Zero line does not start with '0'"
**Fix:** Ensure field starts with '0': `0067l-003...` not `067l-003...`

### "Invalid name format"
**Fix:** Use comma separator: `Smith, John` not `John Smith`

### "No ESID generated"
**Fix:** Populate at least uniqueid or emailaddress for each patron

---

## File Submission

1. Save as `.xlsx` (Excel) or `.csv` (CSV) format
2. Name file descriptively: `YYYY-MM-DD-Stephens-Patrons.xlsx`
3. Submit via MOBIUS secure file transfer
4. Include patron count in submission email

---

## Support

**MOBIUS Consortium Office**
Email: support@mobiusconsortium.org
Website: https://mobiusconsortium.org

---

**Document Version:** 1.0
**Parser Version:** StephensParser.pm (2025-01)

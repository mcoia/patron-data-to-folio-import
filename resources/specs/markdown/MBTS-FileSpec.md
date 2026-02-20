# Midwestern Baptist Theological Seminary (MBTS)
## Patron Data File Specification

**Parser:** MBTSParser
**File Format Supported:** CSV (.csv) only
**Last Updated:** January 2026
**Contact:** MOBIUS Consortium Office

---

## Overview

MBTS uses a **specialized multi-line format** where each patron record spans multiple columns. Column Line1 contains a fixed-length Sierra-style zero line, and columns Line2-Line10 contain tagged fields.

**Key Characteristics:**
- CSV format only (Excel NOT supported)
- Fixed-length 26-character Line1 format
- Tagged fields in Line2-Line10 (first character is tag, remainder is data)
- UTF-8 BOM handling (automatically stripped)
- ESID set directly from email address
- Mixed case column headers (Line1-Line4 capitalized, line5-line10 lowercase)

---

## File Format Requirements

### Character Encoding
- **CSV Only:** UTF-8 with or without BOM (Byte Order Mark)
- Parser automatically strips UTF-8 BOM if present

### File Extension
- `.csv` files only
- Excel files (.xlsx) are NOT supported

### Structure
- **Row 1:** Column headers (case-sensitive - see below)
- **Row 2+:** Patron data

---

## Column Headers (EXACT SPELLING REQUIRED)

**CRITICAL:** Column names are case-sensitive. Line1-Line4 use uppercase "L", line5-line10 use lowercase "l".

| Column Name | Case | Required | Description |
|------------|------|----------|-------------|
| `Line1` | **Uppercase L** | **Yes** | Fixed-length 26-char zero line with patron metadata |
| `Line2` | **Uppercase L** | **Yes** | Tagged name field (tag + name) |
| `Line3` | **Uppercase L** | No | Tagged address field (tag + address) |
| `Line4` | **Uppercase L** | No | Tagged telephone field (tag + phone) |
| `line5` | **Lowercase l** | No | Tagged address2 field (tag + address2) |
| `line6` | **Lowercase l** | No | Tagged telephone2 field (tag + phone2) |
| `line7` | **Lowercase l** | No | Tagged department field (tag + dept) |
| `line8` | **Lowercase l** | No | Tagged unique_id field (tag + ID) |
| `line9` | **Lowercase l** | No | Tagged barcode field (tag + barcode) |
| `line10` | **Lowercase l** | **Yes** | Tagged email field (tag + email) |

---

## Line1: Fixed-Length Format (26 Characters)

Line1 contains a 26-character fixed-length field with Sierra-style zero line metadata.

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
Position 16-25:   Expiration Date (variable length, extracted via regex)
```

### Example Line1 Values

```
0067--  btg  --05-15-26
0001ab003shb  --12-31-25
0045c-002mbts --06-30-26
```

### Position-by-Position Breakdown

**Example:** `0067--  btg  --05-15-26`

| Positions | Value | Field | Meaning |
|-----------|-------|-------|---------|
| 0 | `0` | Field Code | Always '0' |
| 1-3 | `067` | Patron Type | Type 67 (leading zeros stripped) |
| 4 | `-` | PCODE1 | Hyphen = not defined |
| 5 | `-` | PCODE2 | Hyphen = not defined |
| 6-8 | `   ` | PCODE3 | Three spaces = not defined |
| 9-13 | `btg  ` | Home Library | "btg" + 2 spaces = 5 chars |
| 14 | ` ` | Message Code | Space = none |
| 15 | `-` | Block Code | Hyphen = none |
| 16+ | `05-15-26` | Expiration | May 15, 2026 |

### Supported Date Formats in Line1
- `mm-dd-yy` (e.g., `05-15-26`)
- `mm/dd/yyyy` (e.g., `05/15/2026`)
- `mm.dd.yyyy` (e.g., `05.15.2026`)

Date is extracted using regex from end of string.

---

## Tagged Fields Format (Line2-Line10)

Columns Line2 through Line10 use a **tagged field format** where:
- **First character:** Field tag (identifies the field type)
- **Remaining characters:** Field data

### Tag Definitions

| Line | Tag Character | Field | Example |
|------|---------------|-------|---------|
| Line2 | `n` | Name | `nSmith, John A` |
| Line3 | `a` | Address | `a123 Main St$Springfield, MO` |
| Line4 | `t` | Telephone | `t573-123-4567` |
| line5 | `h` | Address2 (home) | `h456 Oak Ave$Columbia, MO` |
| line6 | `p` | Telephone2 | `p573-987-6543` |
| line7 | `d` | Department | `dTheology` |
| line8 | `u` | Unique ID | `u12345678` |
| line9 | `b` | Barcode | `b87654321` |
| line10 | `z` | Email | `zjohn.smith@mbts.edu` |

### Tagged Field Examples

```
Line2: nDoe, Jane Marie
Line3: a200 Seminary Pl$Kansas City, MO 64145
Line4: t816-555-1234
line5: h
line6: p
line7: d
line8: u23456789
line9: b98765432
line10: zjane.doe@mbts.edu
```

**Note:** Empty fields still have the tag character: `h` means address2 field exists but is empty.

---

## Special Processing Rules

### ESID (External System ID)
Unlike other parsers, MBTS sets ESID **directly from the email address** (line10):
- ESID = email field value
- If email is empty, ESID builder is used as fallback

### UTF-8 BOM Handling
The parser automatically detects and strips UTF-8 Byte Order Mark (BOM) from the first column header if present. Your CSV export tool may add this automatically.

### Department Field
The department field is set to an empty JSON object `"{}"` - this is by design.

---

## Sample Data File

### CSV Format Example

```csv
Line1,Line2,Line3,Line4,line5,line6,line7,line8,line9,line10
0067--  btg  --05-15-26,nSmith, John A,"a123 Main St$Kansas City, MO 64145",t816-123-4567,h,p,d,u12345678,b87654321,zjohn.smith@mbts.edu
0067--  btg  --12-31-25,nDoe, Jane Marie,"a200 Seminary Pl$Kansas City, MO 64145",t816-987-6543,h,p,d,u23456789,b98765432,zjane.doe@mbts.edu
0045c-002mbts--06-30-26,nJohnson, Robert,"a300 E 55th St$Kansas City, MO 64110",t816-555-1234,"h456 Oak Ave$Lee's Summit, MO",p816-555-9999,dTheology,u34567890,b11223344,zrobert.johnson@mbts.edu
```

### Detailed Row Example

**Full patron record for John Smith:**

| Column | Value | After Tag Stripping |
|--------|-------|---------------------|
| Line1 | `0067--  btg  --05-15-26` | *(parsed as fixed-length)* |
| Line2 | `nSmith, John A` | `Smith, John A` |
| Line3 | `a123 Main St$Kansas City, MO 64145` | `123 Main St$Kansas City, MO 64145` |
| Line4 | `t816-123-4567` | `816-123-4567` |
| line5 | `h` | *(empty)* |
| line6 | `p` | *(empty)* |
| line7 | `d` | *(empty)* |
| line8 | `u12345678` | `12345678` |
| line9 | `b87654321` | `87654321` |
| line10 | `zjohn.smith@mbts.edu` | `john.smith@mbts.edu` |

**Resulting patron data:**
- **Patron Type:** 67
- **PCODE1:** `-`
- **PCODE2:** `-`
- **PCODE3:** `   ` (spaces)
- **Home Library:** `btg  `
- **Expiration Date:** `05-15-26`
- **Name:** `Smith, John A`
- **Address:** `123 Main St$Kansas City, MO 64145`
- **Telephone:** `816-123-4567`
- **Unique ID:** `12345678`
- **Barcode:** `87654321`
- **Email:** `john.smith@mbts.edu`
- **ESID:** `john.smith@mbts.edu` (from email)

---

## Validation Checklist

### Required Fields
- ☑ Every row has Line1 with 26-character fixed-length format
- ☑ Line1 starts with '0' character
- ☑ Line2 has name in "Last, First Middle" format with 'n' tag
- ☑ line10 has email address with 'z' tag

### Column Header Validation
- ☑ `Line1`, `Line2`, `Line3`, `Line4` use **uppercase L**
- ☑ `line5`, `line6`, `line7`, `line8`, `line9`, `line10` use **lowercase l**
- ☑ All column headers spelled exactly as shown

### Format Validation
- ☑ Line1 is exactly 26 characters long (including spaces)
- ☑ Each Line2-line10 field starts with appropriate tag character
- ☑ Names use comma separator: "Last, First Middle"
- ☑ CSV file is UTF-8 encoded

### Data Quality
- ☑ Email addresses are valid format
- ☑ Barcodes are unique across all patrons
- ☑ No duplicate patron records
- ☑ Expiration dates are parseable (mm-dd-yy format recommended)

---

## Common Errors

### "Column 'line5' not found"
**Cause:** Used uppercase 'Line5' instead of lowercase 'line5'
**Fix:** Columns line5-line10 must use **lowercase 'l'**

### "Column 'Line1' not found"
**Cause:** Used lowercase 'line1' instead of uppercase 'Line1'
**Fix:** Columns Line1-Line4 must use **uppercase 'L'**

### "Line1 too short"
**Cause:** Line1 field is less than 26 characters
**Fix:** Pad home library to 5 characters, ensure all positions filled

### "Line1 does not start with '0'"
**Cause:** Missing field code character
**Fix:** Ensure Line1 starts with '0': `0067--  btg  --05-15-26`

### "Invalid tag character"
**Cause:** Wrong tag character in tagged field
**Fix:** Use correct tags: n=name, a=address, t=telephone, h=address2, p=telephone2, d=department, u=unique_id, b=barcode, z=email

### "Missing email in line10"
**Cause:** line10 is empty or missing
**Fix:** ESID comes from email - ensure line10 has format `zemail@mbts.edu`

---

## File Preparation Tips

### Creating Line1 Field
Line1 must be exactly 26 characters. Use this template:

```
0[PTY][P1][P2][PC3][LIBRARY][MC][BC][--][DATE]

Where:
PTY = 3-digit patron type (e.g., 067)
P1 = PCODE1 (1 char)
P2 = PCODE2 (1 char)
PC3 = PCODE3 (3 chars, pad with spaces if needed)
LIBRARY = 5-char library code (pad with spaces)
MC = Message code (1 char)
BC = Block code (1 char)
DATE = Expiration date (mm-dd-yy)
```

**Example construction:**
- Patron Type 67 → `067`
- PCODE1 none → `-`
- PCODE2 none → `-`
- PCODE3 none → `   ` (3 spaces)
- Library "btg" → `btg  ` (btg + 2 spaces = 5 chars)
- Message code none → ` ` (space)
- Block code none → `-`
- Expiration 05/15/2026 → `--05-15-26`

Result: `0067--   btg  --05-15-26`

### Adding Tags to Fields
Prefix each Line2-line10 field with its tag character:
- Name: `n` + name → `nSmith, John A`
- Address: `a` + address → `a123 Main St$Kansas City, MO`
- Email: `z` + email → `zjohn.smith@mbts.edu`

Even empty fields need tags: `h`, `p`, `d`

---

## File Submission

1. Save as `.csv` format (Excel NOT supported)
2. Ensure UTF-8 encoding
3. Name file: `YYYY-MM-DD-MBTS-Patrons.csv`
4. Verify column header capitalization (Line1-4 uppercase, line5-10 lowercase)
5. Submit via MOBIUS secure file transfer
6. Include patron count in submission email

---

## Support

**MOBIUS Consortium Office**
Email: support@mobiusconsortium.org
Website: https://mobiusconsortium.org

---

**Document Version:** 1.0
**Parser Version:** MBTSParser.pm (2025-01)

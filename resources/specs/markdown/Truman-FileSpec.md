# Truman State University
## Patron Data File Specification

**Parser:** TrumanParser
**File Format Supported:** Sierra Text File Image (Format 3)
**Last Updated:** January 2026
**Contact:** MOBIUS Consortium Office

---

## Overview

Truman State University uses the **standard Sierra Text File Image format (Format 3)** for patron data exports. This is the official Innovative Interfaces format documented in the Sierra system.

**Key Characteristics:**
- Uses Sierra Text File Image format (Format 3)
- Fixed-length zero line (24 characters) for patron metadata
- Variable-length tagged fields for patron data
- Each field is a new line ending with CR+LF (0D0A)
- Supports optional "Other Barcode 1" custom field

---

## File Format Requirements

### Format Type
**Sierra Text File Image (Format 3)**

This format carries both fixed-length and variable-length data. Each patron record consists of:
1. **Zero field (line 1):** Fixed-length 24-character line with patron metadata
2. **Tagged fields (subsequent lines):** Variable-length lines, each starting with a single-character tag

### Character Encoding
- UTF-8 or ASCII
- Each line ends with carriage return + line feed (CR+LF, hexadecimal 0D0A)

### File Extension
- No specific extension required (commonly `.txt` or no extension)
- Must be text format, not binary

---

## Sierra Zero Line Format (CRITICAL)

The **first line** of each patron record is called the "zero field" because its field tag is '0'. It contains fixed-length patron metadata and is **always exactly 24 characters long**.

### Format Structure (24 Characters)

```
Position 0:       '0' (field code - REQUIRED)
Positions 1-3:    Patron Type (3 digits, 000-255)
Position 4:       PCODE1 (1 character)
Position 5:       PCODE2 (1 character)
Positions 6-8:    PCODE3 (3 digits, 000-255)
Positions 9-13:   Home Library (5 characters, padded with spaces)
Position 14:      Patron Message Code (1 character)
Position 15:      Patron Block Code (1 character)
Positions 16-23:  Expiration Date (8 characters, mm-dd-yy)
```

### Example Zero Lines

```
0001ab001shb --12-31-01
0067--   tru  --05-15-26
0045c-003trumn--06-30-25
```

### Position-by-Position Breakdown

**Example:** `0001ab001shb --12-31-01` (exactly 24 characters)

| Positions | Value | Field | Meaning |
|-----------|-------|-------|---------|
| 0 | `0` | Field Code | Always '0' to indicate zero line |
| 1-3 | `001` | Patron Type | Type 1 |
| 4 | `a` | PCODE1 | Statistical code 1 |
| 5 | `b` | PCODE2 | Statistical code 2 |
| 6-8 | `001` | PCODE3 | Statistical code 3 |
| 9-13 | `shb  ` | Home Library | "shb" + 2 spaces = 5 characters |
| 14 | ` ` | Patron Message Code | Space = no message code |
| 15 | `-` | Patron Block Code | Hyphen = no block |
| 16-23 | `12-31-01` | Expiration Date | December 31, 2001 (mm-dd-yy) |

**CRITICAL:** The zero line MUST be exactly 24 characters. Use hyphens (`-`) or spaces for undefined codes. Pad home library to 5 characters with spaces.

---

## Variable-Length Tagged Fields

Each line following the zero field contains a single-character field tag in the first column, followed by that field's data.

### Sierra Field Tags

| Tag | Field | Required | Description | Example |
|-----|-------|----------|-------------|---------|
| `n` | Name | **Yes** | Patron name in "Last, First Middle" format | `nSmith, Jane Marie` |
| `a` | Address | **Yes** | Primary address; use `$` for line breaks | `a1234 Main St$Kirksville, MO 63501` |
| `t` | Telephone | No | Primary phone number | `t660-785-4000` |
| `h` | Address2 | No | Secondary/permanent address | `h5678 Oak Ave$Columbia, MO 65201` |
| `p` | Telephone2 | No | Secondary phone number | `p660-555-1234` |
| `d` | Department | **Yes** | Library return address (3-char location code) | `dtru` |
| `u` | Unique ID | **Yes** | Patron ID + institution suffix | `u123456789TRU` |
| `b` | Barcode | No | Patron barcode | `b87654321` |
| `z` | Email Address | No | Email address | `zjsmith@truman.edu` |
| `x` | Note | No | Free text note (staff-only) | `xGraduate student` |

### Department Field Format

The `d` (department) field should contain the same three-character bibliographic location code used in the Home Library fixed field, in lowercase letters, with NO trailing spaces.

**Example:**
- If Home Library in zero line is `shb  ` (shb + 2 spaces)
- Department field should be: `dshb` (shb with no spaces)

### Unique ID Format

The Unique ID is a combination of patron identification number and institution alpha suffix:
- **Format:** `{StudentNumber}{InstitutionCode}`
- **Example:** `123456789TRU`
- Institution suffix for Truman: `TRU` (uppercase, no spaces)

---

## Custom Fields (Truman-Specific)

Truman parser supports an optional custom field for additional barcode tracking:

### "Other Barcode 1" Field

If your Sierra export includes a custom field called "Other Barcode 1", it will be processed and converted to:
- **Internal field name:** `otherBarcode`
- **Storage format:** JSON custom field

**This is optional** - if you don't export "Other Barcode 1", the parser works normally.

---

## Sample Sierra Format File

### Text File Format Example

```
0001ab001tru --12-31-26
nSmith, Jane Marie
a1234 Main St$Kirksville, MO 63501
t660-785-4000
h5678 Oak Ave$Columbia, MO 65201
p660-555-1234
dtru
u123456789TRU
b87654321
zjane.smith@truman.edu
xUndergraduate student
0067--   tru  --05-15-27
nDoe, John Alan
a2345 University Ave$Kirksville, MO 63501
t660-785-5000
dtru
u234567890TRU
b98765432
zjohn.doe@truman.edu
0045c-003tru --06-30-26
nJohnson, Maria Elena
a3456 Campus Dr$Kirksville, MO 63501
t660-785-6000
h7890 Elm St$Hannibal, MO 63401
dtru
u345678901TRU
b11223344
zmaria.johnson@truman.edu
xGraduate student
```

### Patron Record Breakdown

**Record 1 (Jane Smith):**
- Zero line: `0001ab001tru --12-31-26`
  - Patron Type: 1, PCODE1: a, PCODE2: b, PCODE3: 001
  - Home Library: tru (+ 2 spaces), Expires: 12-31-26
- Name: `Smith, Jane Marie`
- Primary Address: `1234 Main St$Kirksville, MO 63501`
- Primary Phone: `660-785-4000`
- Secondary Address: `5678 Oak Ave$Columbia, MO 65201`
- Secondary Phone: `660-555-1234`
- Department: `tru`
- Unique ID: `123456789TRU`
- Barcode: `87654321`
- Email: `jane.smith@truman.edu`
- Note: `Undergraduate student`

**Record 2 (John Doe):**
- Zero line: `0067--   tru  --05-15-27`
  - Patron Type: 67, PCODE1: -, PCODE2: -, PCODE3: (spaces)
  - Home Library: tru (+ 2 spaces), Expires: 05-15-27
- Name: `Doe, John Alan`
- Primary Address: `2345 University Ave$Kirksville, MO 63501`
- Primary Phone: `660-785-5000`
- Department: `tru`
- Unique ID: `234567890TRU`
- Barcode: `98765432`
- Email: `john.doe@truman.edu`

---

## Field Descriptions

### Fixed-Length Fields (Zero Line)

**Patron Type (000-255):**
Each library defines patron types determining borrower privileges, renewals, loan periods, notices, and fine amounts.

**PCODE1, PCODE2 (1 character each):**
Statistical subdivision codes determined by the library system. Use hyphen (`-`) if not assigned.

**PCODE3 (000-255):**
Three-digit numeric statistical code. Use three spaces if not assigned on your system.

**Home Library (5 characters):**
Three-character bibliographic location code in lowercase, padded with two spaces.
Examples: `tru  `, `shb  `, `trumn`

**Patron Message Code (1 character):**
Triggers message display when patron record accessed. Use hyphen (`-`) unless defined.

**Patron Block Code (1 character):**
Manual block preventing checkout/renewal. Use hyphen (`-`) unless patron is blocked.

**Patron Expiration Date (mm-dd-yy):**
8 characters in mm-dd-yy format. Examples: `12-31-26`, `05-15-27`

### Variable-Length Fields

**Name:**
Enter as indexed: "Last, First Middle". Displays and prints exactly as entered.

**Address:**
Primary/local address. Use dollar sign (`$`) for line breaks:
- `1234 Main St$Kirksville, MO 63501`

**Address2:**
Secondary/permanent address (e.g., home address for students).

**Department:**
Three-character bibliographic location code (lowercase, no spaces). Must match Home Library code from zero line.

**Unique ID:**
Patron identification number + institution suffix (TRU). Used for:
- Patron login to view account
- Key for updating existing patron records

Format: `{StudentNumber}TRU` (e.g., `123456789TRU`)

---

## Validation Checklist

### Required Elements
- ☑ Every patron has zero line (starts with '0', exactly 24 chars)
- ☑ Every patron has name field (tag 'n')
- ☑ Every patron has address field (tag 'a')
- ☑ Every patron has department field (tag 'd')
- ☑ Every patron has unique ID field (tag 'u')

### Zero Line Validation
- ☑ Zero line is exactly 24 characters long
- ☑ Starts with '0' character
- ☑ Patron type is 3 digits (positions 1-3)
- ☑ Home library is 5 characters (positions 9-13)
- ☑ Expiration date is 8 characters (positions 16-23, format: mm-dd-yy)

### Field Format Validation
- ☑ All names in "Last, First Middle" format
- ☑ Department matches home library code (lowercase, no spaces)
- ☑ Unique IDs end with "TRU" suffix
- ☑ Each tagged field starts with correct tag character

### Line Endings
- ☑ Each line ends with CR+LF (0D0A hex)
- ☑ No extra blank lines between records

### Data Quality
- ☑ No duplicate unique IDs
- ☑ No duplicate barcodes
- ☑ Email addresses are valid format

---

## Common Errors

### "Zero line not 24 characters"
**Cause:** Zero line is too short or too long
**Fix:** Count characters carefully:
- Positions 0-15: metadata (16 chars)
- Positions 16-23: date (8 chars)
- Total: 24 characters exactly

### "Department doesn't match home library"
**Cause:** Department field has different code than home library in zero line
**Fix:** Use same 3-character code in both places:
- Zero line positions 9-11: `tru`
- Department field: `dtru`

### "Unique ID missing TRU suffix"
**Cause:** Unique ID doesn't end with "TRU"
**Fix:** Append "TRU" to student number: `123456789` → `123456789TRU`

### "Invalid name format"
**Cause:** Name not in "Last, First Middle" format
**Fix:** Use comma separator: `Smith, Jane` not `Jane Smith`

### "Line ending issue"
**Cause:** Incorrect line endings (Unix LF only, Mac CR only)
**Fix:** Use Windows-style CR+LF (0D0A) line endings

---

## File Preparation from Sierra

If exporting from Sierra ILS:

1. **Export Format:** Select "Text File Image (Format 3)"
2. **Include Fields:** Ensure zero line and required tagged fields are included
3. **Department Field:** Verify 'd' tag is included with correct location code
4. **Unique ID:** Ensure 'u' tag includes institution suffix "TRU"
5. **Line Endings:** Verify CR+LF format (Windows-style)

---

## File Submission

1. Save as text file (`.txt` or no extension)
2. Ensure CR+LF line endings (Windows-style)
3. Verify zero lines are 24 characters
4. Verify all unique IDs end with "TRU"
5. Name file: `YYYY-MM-DD-Truman-Patrons.txt`
6. Submit via MOBIUS secure file transfer
7. Include patron count in submission email

---

## Technical Reference

For complete details on Sierra Text File Image format (Format 3), see:
- `resources/patron_batchloading.txt` - Official MOBIUS patron batchloading documentation

---

## Support

**MOBIUS Consortium Office**
Email: support@mobiusconsortium.org
Website: https://mobiusconsortium.org

---

**Document Version:** 1.0
**Parser Version:** TrumanParser.pm (2025-01)
**Base Format:** Sierra Text File Image (Format 3)

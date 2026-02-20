# Missouri Western State University
## Patron Data File Specification

**Parser:** MissouriWesternParser
**File Format Supported:** Sierra Text File Image (Format 3)
**Last Updated:** January 2026
**Contact:** MOBIUS Consortium Office

---

## Overview

Missouri Western State University uses the **standard Sierra Text File Image format (Format 3)** with database-driven PCODE field mappings for custom fields.

**Key Characteristics:**
- Uses Sierra Text File Image format (Format 3)
- Fixed-length zero line (24 characters) for patron metadata
- Variable-length tagged fields for patron data
- **Special processing:** PCODE2 and PCODE3 automatically mapped to custom fields (classlevel, department)
- PCODE3 normalized by removing leading zeros
- Each field is a new line ending with CR+LF (0D0A)

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

The **first line** of each patron record is the "zero field" - exactly 24 characters containing fixed-length patron metadata.

### Format Structure (24 Characters)

```
Position 0:       '0' (field code - REQUIRED)
Positions 1-3:    Patron Type (3 digits, 000-255)
Position 4:       PCODE1 (1 character)
Position 5:       PCODE2 (1 character) - IMPORTANT: Mapped to Class Level
Positions 6-8:    PCODE3 (3 digits, 000-255) - IMPORTANT: Mapped to Department
Positions 9-13:   Home Library (5 characters, padded with spaces)
Position 14:      Patron Message Code (1 character)
Position 15:      Patron Block Code (1 character)
Positions 16-23:  Expiration Date (8 characters, mm-dd-yy)
```

### Example Zero Lines

```
0001ab047mow  --12-31-26
0067c-025mwest--05-15-27
0045--012molib--06-30-25
```

### Position-by-Position Breakdown

**Example:** `0001ab047mow  --12-31-26` (exactly 24 characters)

| Positions | Value | Field | Meaning |
|-----------|-------|-------|---------|
| 0 | `0` | Field Code | Always '0' |
| 1-3 | `001` | Patron Type | Type 1 |
| 4 | `a` | PCODE1 | Statistical code 1 |
| 5 | `b` | PCODE2 | **Class Level code** (mapped to "classlevel" field) |
| 6-8 | `047` | PCODE3 | **Department code 47** (mapped to "department" field) |
| 9-13 | `mow  ` | Home Library | "mow" + 2 spaces |
| 14 | ` ` | Message Code | Space = none |
| 15 | `-` | Block Code | Hyphen = none |
| 16-23 | `12-31-26` | Expiration | December 31, 2026 |

**CRITICAL:** Zero line MUST be exactly 24 characters.

---

## PCODE Field Mapping (Missouri Western-Specific Feature)

Missouri Western parser includes **automated PCODE mapping** for PCODE2 and PCODE3 values:

### PCODE2 → Class Level Mapping

PCODE2 values are automatically mapped to class level descriptions.

**Example mappings:**
```
PCODE2 Value → Class Level
a            → "Freshman"
b            → "Sophomore"
c            → "Junior"
d            → "Senior"
f            → "Faculty"
s            → "Staff"
```

### PCODE3 → Department Mapping

PCODE3 values are automatically mapped to department names.

**Important:** Leading zeros are stripped before mapping:
- `047` → `47`
- `012` → `12`
- `003` → `3`

**Example mappings:**
```
PCODE3 Value → Department Name
47           → "Biology"
25           → "Computer Science"
12           → "Mathematics"
3            → "English"
```

### How Mapping Works

1. Parser extracts PCODE2 and PCODE3 from zero line
2. System queries **patron_import.pcode2_mapping** and **patron_import.pcode3_mapping** database tables
3. Values matched to institution-specific mappings
4. Custom fields populated:
   - `classlevel`: PCODE2 mapped value
   - `department`: PCODE3 mapped value (as JSON array)

### Important Notes

- **Mappings are configured in database** - you don't provide them in your file
- **Coordinate with MOBIUS** to ensure your PCODE values match database mappings
- **If PCODE value not found:** Custom fields may be empty or use default
- **Leading zeros stripped from PCODE3** before lookup (047 → 47)

**Action Required:** Contact MOBIUS to verify PCODE2 and PCODE3 values match your institution's database configuration.

---

## Variable-Length Tagged Fields

### Sierra Field Tags

| Tag | Field | Required | Description | Example |
|-----|-------|----------|-------------|---------|
| `n` | Name | **Yes** | "Last, First Middle" format | `nSmith, Jane Marie` |
| `a` | Address | **Yes** | Primary address; `$` for line breaks | `a4525 Downs Dr$St Joseph, MO 64507` |
| `t` | Telephone | No | Primary phone | `t816-271-4200` |
| `h` | Address2 | No | Secondary address | `h123 Main St$Kansas City, MO 64106` |
| `p` | Telephone2 | No | Secondary phone | `p816-555-1234` |
| `d` | Department | **Yes** | 3-char location code (lowercase) | `dmow` |
| `u` | Unique ID | **Yes** | Student ID + "MOWEST" suffix | `u123456789MOWEST` |
| `b` | Barcode | No | Patron barcode | `b87654321` |
| `z` | Email | No | Email address | `zjsmith@missouriwestern.edu` |
| `x` | Note | No | Staff-only note | `xTransfer student` |

### Department Field

Department should contain the three-character bibliographic location code (lowercase, no spaces) matching the Home Library field.

### Unique ID Format

**Format:** `{StudentNumber}MOWEST`
**Example:** `123456789MOWEST`

The institution suffix for Missouri Western is **MOWEST** (uppercase, no spaces).

---

## Sample Sierra Format File

```
0001ab047mow  --12-31-26
nSmith, Jane Marie
a4525 Downs Dr$St Joseph, MO 64507
t816-271-4200
h123 Main St$Kansas City, MO 64106
dmow
u123456789MOWEST
b87654321
zjane.smith@missouriwestern.edu
0067c-025mwest--05-15-27
nDoe, John Alan
a1234 Mitchell Ave$St Joseph, MO 64507
t816-271-5000
dmwest
u234567890MOWEST
b98765432
zjohn.doe@missouriwestern.edu
xSophomore, Biology major
0045--012molib--06-30-26
nJohnson, Maria Elena
a5678 Frederick Ave$St Joseph, MO 64506
t816-271-6000
dmolib
u345678901MOWEST
b11223344
zmaria.johnson@missouriwestern.edu
```

### Record Example with PCODE Mapping

**Input (John Doe):**
```
Zero line: 0067c-025mwest--05-15-27
PCODE2: c
PCODE3: 025
```

**After database mapping:**
```
PCODE2: c → Class Level: "Junior"
PCODE3: 025 → 25 → Department: "Computer Science"
```

**Result:**
- **classlevel custom field:** `"Junior"`
- **department field:** `["Computer Science"]` (JSON array)

---

## Validation Checklist

### Required Elements
- ☑ Every patron has zero line (exactly 24 characters, starts with '0')
- ☑ Every patron has name field (tag 'n')
- ☑ Every patron has address field (tag 'a')
- ☑ Every patron has department field (tag 'd')
- ☑ Every patron has unique ID field (tag 'u')
- ☑ **Unique IDs end with "MOWEST" suffix**

### Zero Line Validation
- ☑ Exactly 24 characters long
- ☑ PCODE2 (position 5) matches valid class level codes
- ☑ PCODE3 (positions 6-8) matches valid department codes
- ☑ Home library is 5 characters (positions 9-13)
- ☑ Expiration date is 8 characters (positions 16-23, mm-dd-yy)

### Field Validation
- ☑ Names in "Last, First Middle" format
- ☑ Department field matches home library code
- ☑ Each tagged field starts with correct tag

### PCODE Coordination
- ☑ PCODE2 values coordinated with MOBIUS (match database mappings)
- ☑ PCODE3 values coordinated with MOBIUS (match database mappings)

---

## Common Errors

### "PCODE2 not found in mapping table"
**Cause:** PCODE2 value doesn't exist in database configuration
**Fix:** Contact MOBIUS to verify PCODE2 values match your institution's class level codes

### "PCODE3 not found in mapping table"
**Cause:** PCODE3 value doesn't exist in database configuration
**Fix:** Contact MOBIUS to verify PCODE3 values match your institution's department codes

**Note:** Leading zeros are stripped from PCODE3 before lookup:
- Zero line has `047` → System looks up `47`
- Zero line has `012` → System looks up `12`
- Zero line has `003` → System looks up `3`

### "Unique ID missing MOWEST suffix"
**Cause:** Unique ID doesn't end with "MOWEST"
**Fix:** Add suffix: `123456789` → `123456789MOWEST`

### "Department doesn't match home library"
**Cause:** Different codes used
**Fix:** Use same code in both places:
- Zero line: `mow  ` → Department: `dmow`

---

## PCODE Coordination with MOBIUS

**Before submitting files, coordinate with MOBIUS on:**

### PCODE2 (Class Level) Codes
Verify your institution's class level codes are configured in the database:
- What code represents Freshman? Sophomore? Junior? Senior?
- What codes for Faculty, Staff, Alumni, etc.?
- Ensure zero line PCODE2 values match configured codes

### PCODE3 (Department) Codes
Verify your institution's department codes are configured:
- What code represents each academic department?
- Remember: leading zeros are stripped (047 → 47)
- Ensure your codes don't conflict after zero-stripping:
  - `047` and `47` both become `47` in lookup
  - `003` and `3` both become `3` in lookup

**Contact MOBIUS well before your first file submission** to configure these mappings.

---

## File Submission

1. Save as text file (`.txt` or no extension)
2. Ensure CR+LF line endings
3. Verify zero lines are exactly 24 characters
4. Verify all unique IDs end with "MOWEST"
5. **Coordinate PCODE mappings with MOBIUS first**
6. Name file: `YYYY-MM-DD-MissouriWestern-Patrons.txt`
7. Submit via MOBIUS secure file transfer
8. Include patron count in submission email

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
**Parser Version:** MissouriWesternParser.pm (2025-01)
**Base Format:** Sierra Text File Image (Format 3)

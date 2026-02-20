# Covenant College
## Patron Data File Specification

**Parser:** CovenantParser
**File Format Supported:** Sierra Text File Image (Format 3)
**Last Updated:** January 2026
**Contact:** MOBIUS Consortium Office

---

## Overview

Covenant College uses the **standard Sierra Text File Image format (Format 3)** for patron data exports. The parser includes special processing to map PCODE3 values to department names.

**Key Characteristics:**
- Uses Sierra Text File Image format (Format 3)
- Fixed-length zero line (24 characters) for patron metadata
- Variable-length tagged fields for patron data
- PCODE3 values automatically mapped to department names via system lookup
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
Position 5:       PCODE2 (1 character)
Positions 6-8:    PCODE3 (3 digits, 000-255) - IMPORTANT for department mapping
Positions 9-13:   Home Library (5 characters, padded with spaces)
Position 14:      Patron Message Code (1 character)
Position 15:      Patron Block Code (1 character)
Positions 16-23:  Expiration Date (8 characters, mm-dd-yy)
```

### Example Zero Lines

```
0001ab025cov  --12-31-26
0067--012cove --05-15-27
0045c-003cvnt --06-30-25
```

### Position-by-Position Breakdown

**Example:** `0001ab025cov  --12-31-26` (exactly 24 characters)

| Positions | Value | Field | Meaning |
|-----------|-------|-------|---------|
| 0 | `0` | Field Code | Always '0' |
| 1-3 | `001` | Patron Type | Type 1 |
| 4 | `a` | PCODE1 | Statistical code 1 |
| 5 | `b` | PCODE2 | Statistical code 2 |
| 6-8 | `025` | PCODE3 | **Dept code 25** (mapped to dept name) |
| 9-13 | `cov  ` | Home Library | "cov" + 2 spaces |
| 14 | ` ` | Message Code | Space = none |
| 15 | `-` | Block Code | Hyphen = none |
| 16-23 | `12-31-26` | Expiration | December 31, 2026 |

**CRITICAL:** The zero line MUST be exactly 24 characters. Use hyphens (`-`) or spaces for undefined codes. Pad home library to 5 characters.

---

## PCODE3 Department Mapping (Covenant-Specific Feature)

Covenant parser includes **automated department mapping** for PCODE3 values:

### How It Works
1. Parser extracts PCODE3 value from zero line (positions 6-8)
2. System queries FOLIO API to get department list for your tenant
3. PCODE3 value is matched against department codes
4. Matching department name is automatically populated

### Example Mapping
```
PCODE3 Value → Department Name
025          → "School of Arts and Sciences"
012          → "School of Education"
003          → "School of Business"
```

### Important Notes
- **You don't configure this mapping** - it's retrieved from FOLIO system automatically
- **PCODE3 must match** values in your FOLIO department configuration
- **If no match found:** Department field may be empty or use default
- **Consult MOBIUS** if you need to update department mappings in FOLIO

**Action Required:** Ensure PCODE3 values in your export match the department codes configured in your FOLIO tenant.

---

## Variable-Length Tagged Fields

Each line following the zero field contains a single-character field tag + data.

### Sierra Field Tags

| Tag | Field | Required | Description | Example |
|-----|-------|----------|-------------|---------|
| `n` | Name | **Yes** | "Last, First Middle" format | `nSmith, Jane Marie` |
| `a` | Address | **Yes** | Primary address; `$` for line breaks | `a123 Main St$Lookout Mountain, GA 30750` |
| `t` | Telephone | No | Primary phone | `t706-820-1560` |
| `h` | Address2 | No | Secondary address | `h456 Oak Ave$Chattanooga, TN 37403` |
| `p` | Telephone2 | No | Secondary phone | `p706-555-1234` |
| `d` | Department | **Yes** | 3-char location code (lowercase, no spaces) | `dcov` |
| `u` | Unique ID | **Yes** | Student ID + "COV" suffix | `u123456789COV` |
| `b` | Barcode | No | Patron barcode | `b87654321` |
| `z` | Email | No | Email address | `zjsmith@covenant.edu` |
| `x` | Note | No | Staff-only note | `xSenior student` |

### Department Field Format

Department should contain the three-character bibliographic location code from Home Library field (lowercase, no spaces).

**Example:**
- Zero line home library: `cov  ` (positions 9-13)
- Department field: `dcov` (no spaces)

### Unique ID Format

**Format:** `{StudentNumber}COV`
**Example:** `123456789COV`

The institution suffix for Covenant is **COV** (uppercase, no spaces).

---

## Sample Sierra Format File

```
0001ab025cov  --12-31-26
nSmith, Jane Marie
a123 Main St$Lookout Mountain, GA 30750
t706-820-1560
h456 Oak Ave$Chattanooga, TN 37403
dcov
u123456789COV
b87654321
zjane.smith@covenant.edu
xSenior, Arts & Sciences
0067--012cove --05-15-27
nDoe, John Alan
a2345 College Dr$Lookout Mountain, GA 30750
t706-820-2000
dcove
u234567890COV
b98765432
zjohn.doe@covenant.edu
xFreshman, Education
0045c-003cvnt --06-30-26
nJohnson, Maria Elena
a3456 Campus Way$Lookout Mountain, GA 30750
t706-820-3000
dcvnt
u345678901COV
b11223344
zmaria.johnson@covenant.edu
```

---

## Validation Checklist

### Required Elements
- ☑ Every patron has zero line (exactly 24 characters, starts with '0')
- ☑ Every patron has name field (tag 'n')
- ☑ Every patron has address field (tag 'a')
- ☑ Every patron has department field (tag 'd')
- ☑ Every patron has unique ID field (tag 'u')

### Zero Line Validation
- ☑ Exactly 24 characters long
- ☑ PCODE3 (positions 6-8) matches valid department codes in FOLIO
- ☑ Home library is 5 characters (positions 9-13)
- ☑ Expiration date is 8 characters (positions 16-23, mm-dd-yy format)

### Field Validation
- ☑ Names use "Last, First Middle" format
- ☑ Department matches home library code
- ☑ Unique IDs end with "COV" suffix
- ☑ Each tagged field starts with correct tag

### Line Endings
- ☑ Lines end with CR+LF (Windows-style)

---

## Common Errors

### "PCODE3 not found in department mapping"
**Cause:** PCODE3 value in zero line doesn't match any department in FOLIO
**Fix:** Contact MOBIUS to verify PCODE3 values match your FOLIO department configuration

### "Department doesn't match home library"
**Cause:** Different codes in zero line vs department field
**Fix:** Use same code: zero line `cov  ` → department field `dcov`

### "Unique ID missing COV suffix"
**Cause:** Unique ID doesn't end with "COV"
**Fix:** Add "COV" suffix: `123456789` → `123456789COV`

### "Zero line wrong length"
**Cause:** Zero line not exactly 24 characters
**Fix:** Pad home library to 5 characters, ensure expiration date is 8 characters

---

## Department Mapping Coordination

**Before submitting files:**
1. Contact MOBIUS to confirm your FOLIO department configuration
2. Verify PCODE3 codes in your zero lines match FOLIO department codes
3. Test with small batch to verify mapping works correctly

**The parser queries FOLIO API automatically** - you don't need to provide department names in your file, just ensure PCODE3 values are correct.

---

## File Submission

1. Save as text file (`.txt` or no extension)
2. Ensure CR+LF line endings
3. Verify zero lines are exactly 24 characters
4. Verify all unique IDs end with "COV"
5. Confirm PCODE3 values match your FOLIO configuration (contact MOBIUS)
6. Name file: `YYYY-MM-DD-Covenant-Patrons.txt`
7. Submit via MOBIUS secure file transfer

---

## Support

**MOBIUS Consortium Office**
Email: support@mobiusconsortium.org
Website: https://mobiusconsortium.org

---

**Document Version:** 1.0
**Parser Version:** CovenantParser.pm (2025-01)
**Base Format:** Sierra Text File Image (Format 3)

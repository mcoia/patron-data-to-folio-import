# Kansas City Kansas Community College (KCKCC)
## Patron Data File Specification

**Parser:** KCKCCParser
**File Format Supported:** Sierra Text File Image (Format 3)
**Last Updated:** January 2026
**Contact:** MOBIUS Consortium Office

---

## Overview

Kansas City Kansas Community College uses the **standard Sierra Text File Image format (Format 3)** with special barcode extraction from unique ID.

**Key Characteristics:**
- Uses Sierra Text File Image format (Format 3)
- Fixed-length zero line (24 characters) for patron metadata
- Variable-length tagged fields for patron data
- **Special processing:** Barcode automatically extracted from unique_id by removing "KCKCC" suffix
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
Positions 6-8:    PCODE3 (3 digits, 000-255)
Positions 9-13:   Home Library (5 characters, padded with spaces)
Position 14:      Patron Message Code (1 character)
Position 15:      Patron Block Code (1 character)
Positions 16-23:  Expiration Date (8 characters, mm-dd-yy)
```

### Example Zero Lines

```
0001ab001kck --12-31-26
0067--   kckcc--05-15-27
0045c-003kclib--06-30-25
```

### Position-by-Position Breakdown

**Example:** `0001ab001kck --12-31-26` (exactly 24 characters)

| Positions | Value | Field | Meaning |
|-----------|-------|-------|---------|
| 0 | `0` | Field Code | Always '0' |
| 1-3 | `001` | Patron Type | Type 1 |
| 4 | `a` | PCODE1 | Statistical code 1 |
| 5 | `b` | PCODE2 | Statistical code 2 |
| 6-8 | `001` | PCODE3 | Statistical code 3 |
| 9-13 | `kck  ` | Home Library | "kck" + 2 spaces = 5 chars |
| 14 | ` ` | Message Code | Space = none |
| 15 | `-` | Block Code | Hyphen = none |
| 16-23 | `12-31-26` | Expiration | December 31, 2026 |

**CRITICAL:** Zero line MUST be exactly 24 characters. Use hyphens (`-`) or spaces for undefined codes. Pad home library to 5 characters.

---

## Variable-Length Tagged Fields

### Sierra Field Tags

| Tag | Field | Required | Description | Example |
|-----|-------|----------|-------------|---------|
| `n` | Name | **Yes** | "Last, First Middle" format | `nSmith, Jane Marie` |
| `a` | Address | **Yes** | Primary address; `$` for line breaks | `a7250 State Ave$Kansas City, KS 66112` |
| `t` | Telephone | No | Primary phone | `t913-334-1100` |
| `h` | Address2 | No | Secondary address | `h123 Oak St$Kansas City, KS 66101` |
| `p` | Telephone2 | No | Secondary phone | `p913-555-1234` |
| `d` | Department | **Yes** | 3-char location code (lowercase) | `dkck` |
| `u` | Unique ID | **Yes** | Student ID + "KCKCC" suffix | `u123456789KCKCC` |
| `b` | Barcode | No | **Optional** - auto-extracted from unique_id | `b87654321` |
| `z` | Email | No | Email address | `zjsmith@kckcc.edu` |
| `x` | Note | No | Staff-only note | `xTransfer student` |

---

## CRITICAL: Unique ID and Barcode Relationship

**KCKCC-Specific Processing:**

The parser automatically extracts the barcode from the unique_id field by **removing the "KCKCC" suffix**.

### How It Works

**Input unique_id (u tag):**
```
u123456789KCKCC
```

**Parser processing:**
1. Reads unique_id: `123456789KCKCC`
2. Removes "KCKCC" suffix
3. Sets barcode: `123456789`

**Result:**
- **unique_id:** `123456789KCKCC` (stored as-is)
- **barcode:** `123456789` (extracted automatically)

### Important Implications

1. **Barcode field (b tag) is OPTIONAL** in your Sierra export
   - If you include `b` tag, that value is used
   - If you omit `b` tag, parser extracts barcode from unique_id automatically

2. **Unique ID MUST end with "KCKCC"**
   - Format: `{StudentNumber}KCKCC`
   - Example: `123456789KCKCC`
   - If suffix is missing, barcode extraction won't work properly

3. **Barcode = Student Number**
   - The part before "KCKCC" becomes the barcode
   - Example: `123456789KCKCC` → barcode `123456789`

### Recommended Approach

**Option 1 (Recommended):** Include both fields explicitly
```
u123456789KCKCC
b123456789
```

**Option 2:** Omit barcode field, rely on auto-extraction
```
u123456789KCKCC
(no b field - barcode extracted automatically)
```

Both options produce the same result, but Option 1 is clearer and more explicit.

---

## Sample Sierra Format File

```
0001ab001kck --12-31-26
nSmith, Jane Marie
a7250 State Ave$Kansas City, KS 66112
t913-334-1100
h123 Oak St$Kansas City, KS 66101
dkck
u123456789KCKCC
b123456789
zjane.smith@kckcc.edu
0067--   kckcc--05-15-27
nDoe, John Alan
a1234 Metropolitan Ave$Kansas City, KS 66102
t913-334-2000
dkckcc
u234567890KCKCC
zjohn.doe@kckcc.edu
0045c-003kclib--06-30-26
nJohnson, Maria Elena
a5678 State Ave Bldg A$Kansas City, KS 66112
t913-334-3000
h7890 Parallel Pkwy$Kansas City, KS 66104
dkclib
u345678901KCKCC
b345678901
zmaria.johnson@kckcc.edu
xNon-degree seeking
```

### Patron Record Breakdown

**Record 1 (Jane Smith):**
- Zero line: `0001ab001kck --12-31-26`
- Name: `Smith, Jane Marie`
- Unique ID: `123456789KCKCC`
- Barcode (explicit): `123456789`
- **Result:** barcode field used as-is

**Record 2 (John Doe):**
- Zero line: `0067--   kckcc--05-15-27`
- Name: `Doe, John Alan`
- Unique ID: `234567890KCKCC`
- Barcode (omitted): *(none provided)*
- **Result:** barcode auto-extracted as `234567890`

---

## Department Field Format

Department should contain the same three-character bibliographic location code from the Home Library field in lowercase with no trailing spaces.

**Examples:**
- Home Library: `kck  ` → Department: `dkck`
- Home Library: `kckcc` → Department: `dkckcc`
- Home Library: `kclib` → Department: `dkclib`

---

## Validation Checklist

### Required Elements
- ☑ Every patron has zero line (exactly 24 characters, starts with '0')
- ☑ Every patron has name field (tag 'n')
- ☑ Every patron has address field (tag 'a')
- ☑ Every patron has department field (tag 'd')
- ☑ Every patron has unique ID field (tag 'u')
- ☑ **Unique IDs end with "KCKCC" suffix**

### Zero Line Validation
- ☑ Exactly 24 characters long
- ☑ Starts with '0' character
- ☑ Home library is 5 characters (positions 9-13)
- ☑ Expiration date is 8 characters (positions 16-23, mm-dd-yy)

### Field Validation
- ☑ Names in "Last, First Middle" format
- ☑ Department matches home library code (lowercase)
- ☑ Unique IDs end with "KCKCC"
- ☑ Barcode field is either omitted OR matches student number from unique_id

### Line Endings
- ☑ Lines end with CR+LF (Windows-style)

---

## Common Errors

### "Barcode doesn't match unique_id"
**Cause:** Explicit barcode field doesn't match student number portion of unique_id
**Fix:** Either:
- Option A: Omit `b` tag entirely (let parser extract from unique_id)
- Option B: Ensure `b` tag value matches unique_id before "KCKCC"

**Example:**
- unique_id: `u123456789KCKCC`
- barcode: `b123456789` ✓ Correct
- barcode: `b987654321` ✗ Incorrect (doesn't match)

### "Unique ID missing KCKCC suffix"
**Cause:** Unique ID doesn't end with "KCKCC"
**Fix:** Add "KCKCC" suffix: `123456789` → `123456789KCKCC`

### "Department mismatch"
**Cause:** Department field doesn't match home library
**Fix:** Use same 3-char code:
- Zero line: `kck  ` (positions 9-13)
- Department: `dkck`

### "Zero line wrong length"
**Cause:** Zero line not exactly 24 characters
**Fix:** Ensure all positions filled, pad home library to 5 chars, date is 8 chars

---

## File Preparation from Sierra

If exporting from Sierra ILS:

1. **Export Format:** Select "Text File Image (Format 3)"
2. **Unique ID Format:** Ensure unique_id includes "KCKCC" suffix
3. **Barcode Field:**
   - **Recommended:** Include `b` tag with explicit barcode value
   - **Alternative:** Omit `b` tag, rely on auto-extraction
4. **Department:** Ensure 'd' tag matches home library code
5. **Line Endings:** Verify CR+LF format (Windows-style)

---

## File Submission

1. Save as text file (`.txt` or no extension)
2. Ensure CR+LF line endings
3. Verify zero lines are exactly 24 characters
4. Verify all unique IDs end with "KCKCC"
5. Name file: `YYYY-MM-DD-KCKCC-Patrons.txt`
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
**Parser Version:** KCKCCParser.pm (2025-01)
**Base Format:** Sierra Text File Image (Format 3)

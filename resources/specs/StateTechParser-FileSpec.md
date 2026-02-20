# State Tech Parser - File Specification

## Institution
**State Technical College of Missouri (State Tech)**

## Parser Class
`Parsers::StateTechParser`

## Parent Class
Extends `ParserInterface` (independent implementation)

## File Format
**CSV or Excel (XLSX)** - Auto-detects based on file extension
- `.xlsx` → Excel 2007+ format
- Other → CSV format

---

## Expected Column Headers

| Column Name | Required | Data Type | Description |
|-------------|----------|-----------|-------------|
| fullname | Yes | Text | Full name in "Last, First Middle" format |
| PTYPE & Expiration | Yes | Text | Sierra zero line (hybrid format) |
| address | No | Text | Primary address (use `$` for line break) |
| mobilephone | No | Text | Primary telephone |
| username | No | Text | Unique login ID (primary for unique_id) |
| Barcode | No | Text | Library barcode |
| emailaddress | No | Text | Email address |
| externalID | No | Text | External System ID |

**Alternative Column Names:**
- `Expiration Date` → Fallback for `PTYPE & Expiration`
- `uniqueid` → Fallback for `username`
- `Student ID Barcode Number` → Fallback for `Barcode`

---

## Zero Line Format (State Tech Hybrid)

**Example:** `0061l-000lsb  --05/17/2026`

### Format: Follows Standard Sierra Positions 0-15 + Extended Date

| Position | Length | Field Name | Description |
|----------|--------|------------|-------------|
| 0 | 1 | Field Code | Always `0` |
| 1-3 | 3 | Patron Type | Numeric (000-255) |
| 4 | 1 | PCODE1 | Statistical code |
| 5 | 1 | PCODE2 | Statistical code |
| 6-8 | 3 | PCODE3 | Statistical code (000-255) |
| 9-13 | 5 | Home Library | 3-char code + 2 spaces |
| 14 | 1 | Patron Message Code | Message trigger |
| 15 | 1 | Patron Block Code | Manual block |
| 16+ | varies | Expiration Date | **Non-standard:** `mm/dd/yyyy` format |

**Key Difference from Standard Sierra:**
- Uses `mm/dd/yyyy` date format (10 chars) instead of `mm-dd-yy` (8 chars)
- Total length: 26+ characters instead of 24

### Detection Patterns
1. **State Tech Hybrid:** `^0\d{3}l` (zero + 3 digits + 'l')
2. **Standard Sierra:** `^0` (zero + standard format)

---

## Field Requirements

### Required Fields
- **fullname** - Used to parse name components
- **PTYPE & Expiration** or **Expiration Date** - Contains zero line
- **ESID** - Patron skipped if empty (from externalID or ESID builder)

### Optional Fields
- All other fields have defaults or fallbacks

---

## Special Processing

### Name Parsing
Parses "Last, First Middle" format into components:
```
Input: "Smith, John Q"
→ lastName: "Smith"
→ firstName: "John"
→ middleName: "Q"
Output: "Smith, John Q" (rejoined)
```

### Address Parsing
Splits on `$` character:
```
Input: "123 Main St$Springfield, MO 65801"
→ address: "123 Main St"
→ address2: "Springfield, MO 65801"
```

### NULL String Sanitization
Converts literal "NULL" or "null" strings to empty:
```perl
my $sanitize = sub {
    my $value = shift;
    return "" unless defined $value;
    return "" if ($value eq "NULL" || $value eq "null");
    return $value;
};
```

Applied to all text fields: fullname, address, mobilephone, username, email, etc.

### Field Priority/Fallbacks
```perl
unique_id: username → uniqueid → emailaddress
barcode: Barcode → "Student ID Barcode Number"
zero_line: "PTYPE & Expiration" → "Expiration Date"
```

---

## Data Transformations

### Patron Type
```perl
$patronType = substr($zeroLine, 1, 3) + 0;  # "061" → 61
```

### PCODE Fields
```perl
$pcode1 = substr($zeroLine, 4, 1);   # Position 4
$pcode2 = substr($zeroLine, 5, 1);   # Position 5
$pcode3 = substr($zeroLine, 6, 3);   # Positions 6-8
```

### Home Library
```perl
$homeLibrary = substr($zeroLine, 9, 5);  # "lsb  " (5 chars with padding)
```

### Expiration Date
```perl
($expirationDate) = $zeroLine =~ /(\d{1,2}[\-\/\.]\d{1,2}[\-\/\.]\d{2,4})\s*$/;
```
Supports: `05/17/2026`, `05-17-26`, `5/17/2026`, etc.

---

## Example CSV File

```csv
fullname,PTYPE & Expiration,address,mobilephone,username,externalID,emailaddress,Barcode
"Smith, John Q","0061l-000lsb  --05/17/2026","123 Main St$Springfield, MO 65801","5735551234","00123456STC","john.smith@iam.statetechmo.edu","john.smith@iam.statetechmo.edu","123456"
```

**Parsed Result:**
- name: "Smith, John Q"
- patron_type: 61
- pcode1: "l"
- pcode2: "-"
- pcode3: "000"
- home_library: "lsb  "
- patron_message_code: "-"
- patron_block_code: "-"
- patron_expiration_date: "05/17/2026"
- address: "123 Main St"
- address2: "Springfield, MO 65801"
- telephone: "5735551234"
- unique_id: "00123456STC"
- barcode: "123456"
- email_address: "john.smith@iam.statetechmo.edu"
- esid: "john.smith@iam.statetechmo.edu"

---

## Example Excel File

**Sheet 1, Row 1 (Headers):**
```
| fullname | PTYPE & Expiration | address | ... |
```

**Row 2+ (Data):**
```
| Smith, John Q | 0061l-000lsb  --05/17/2026 | 123 Main St$... | ... |
```

**XML Entity Handling:**
- Excel reader converts `&amp;` → `&` in headers
- Applied during header reading

---

## Error Handling
- Missing zero line: Fields default to empty strings
- NULL strings: Converted to empty via sanitize helper
- Missing columns: Fallback column names tried
- Invalid zero line: Try/catch blocks prevent crashes
- Excel read errors: Die with error message

---

## Duplicate Detection
- Uses fingerprinting with exact string comparison
- Checks against all previously parsed patrons
- Duplicates not added to output

---

## Notes
- **Hybrid Format:** Unique to State Tech (standard Sierra positions + extended date)
- **NULL Handling:** Only parser with comprehensive NULL sanitization
- **Dual Format:** Supports both CSV and XLSX seamlessly
- **Fallback Columns:** Multiple column name variations supported
- **Zero-Safe:** Sanitize function handles "0" correctly (not treated as false)

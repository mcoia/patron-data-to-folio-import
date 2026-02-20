# MBTS Parser - File Specification

## Institution
**Midwestern Baptist Theological Seminary (MBTS)**

## Parser Class
`Parsers::MBTSParser`

## Parent Class
Extends `ParserInterface` (independent implementation)

## File Format
**CSV (Comma-Separated Values)** with UTF-8 encoding

**Special Handling:**
- UTF-8 BOM (`\x{FEFF}`) automatically stripped from first column header
- Expects exactly 10 columns in specific order

---

## File Structure

### CSV Column Structure (10 Required Columns)

| Column | Name | Required | Data Type | Description |
|--------|------|----------|-----------|-------------|
| 1 | Line1 | Yes | Text (26 chars) | Fixed-length field with all codes and dates |
| 2 | Line2 | Yes | Tagged | Name (format: `n<value>`) |
| 3 | Line3 | Yes | Tagged | Address (format: `a<value>`) |
| 4 | Line4 | Yes | Tagged | Telephone (format: `t<value>`) |
| 5 | line5 | Yes | Tagged | Address2 (format: `h<value>`) |
| 6 | line6 | Yes | Tagged | Telephone2 (format: `p<value>`) |
| 7 | line7 | Yes | Tagged | Department (format: `d<value>`) |
| 8 | line8 | Yes | Tagged | Unique ID (format: `u<value>`) |
| 9 | line9 | Yes | Tagged | Barcode (format: `b<value>`) |
| 10 | line10 | Yes | Tagged | Email (format: `z<value>`) |

**Note:** Columns 1-4 use capital 'L', columns 5-10 use lowercase 'l'

---

## Line1: Fixed-Length Field Format (26 Characters)

```
Format: "0067--  btg  --05-15-26"
         ^^^^^^^^^^^^^^ ^^^^^^^^
         Codes (16)     Date (10)
```

| Position | Length | Field Name | Description | Extraction |
|----------|--------|------------|-------------|------------|
| 0 | 1 | (unused) | Padding | Skipped |
| 1-3 | 3 | Patron Type | Numeric (000-255) | `substr($line1, 1, 3) + 0` |
| 4 | 1 | PCODE1 | Statistical code | `substr($line1, 4, 1)` |
| 5 | 1 | PCODE2 | Statistical code | `substr($line1, 5, 1)` |
| 6-8 | 3 | PCODE3 | Statistical code | `substr($line1, 6, 3)` |
| 9-13 | 5 | Home Library | 3-char code + spaces | `substr($line1, 9, 5)` |
| 14 | 1 | Patron Message Code | Message trigger | `substr($line1, 14, 1)` |
| 15 | 1 | Patron Block Code | Manual block | `substr($line1, 15, 1)` |
| 16-25 | varies | Expiration Date | Date (flexible format) | Regex: `(\d{1,2}[\-\/\.]\d{1,2}[\-\/\.]\d{2,4})` |

---

## Tagged Fields Format (Line2-Line10)

### Structure
Each field starts with a tag character (first char), followed by the value:

```
Format: T<value>
```

| Format | Tag | Field | Example |
|--------|-----|-------|---------|
| `n<value>` | n | Name | `nSmith, John Q` |
| `a<value>` | a | Address | `a123 Main St$Springfield, MO 65801` |
| `t<value>` | t | Telephone | `t(417) 555-1234` |
| `h<value>` | h | Address2 | `hP.O. Box 456` |
| `p<value>` | p | Telephone2 | `p(417) 555-5678` |
| `d<value>` | d | Department | `dbtg` |
| `u<value>` | u | Unique ID | `u12345678MBTS` |
| `b<value>` | b | Barcode | `b21714123456789` |
| `z<value>` | z | Email | `zjsmith@mbts.edu` |

**Extraction:**
```perl
$value = substr($field, 1);  # Strip first character (tag)
```

---

## Field Requirements

### Required Fields
- **Line1** - Must be parseable (26 chars expected)
- **Email (line10)** - Primary source for ESID
- **ESID** - Patron skipped if empty after all fallbacks

### Optional Fields
- All other fields can be empty
- Missing tagged values result in empty strings

---

## Special Processing

### ESID Assignment Priority
1. **Primary:** Email field (line10/column 10)
   ```perl
   $patron->{esid} = $email;
   ```
2. **Fallback:** ESID builder if email empty
3. **Skip:** Patron not included if ESID remains empty

### UTF-8 BOM Handling
First column header automatically cleaned:
```perl
$headers->[0] =~ s/^\x{FEFF}//;  # Strip UTF-8 BOM
```

### Expiration Date Parsing
Flexible regex supports multiple formats:
- `mm-dd-yy`: "05-15-26"
- `mm/dd/yyyy`: "05/15/2026"
- `m-d-yy`: "5-15-26"

Pattern: `\d{1,2}[\-\/\.]\d{1,2}[\-\/\.]\d{2,4}`

### Patron Type Conversion
```perl
$patronType = substr($fixedField, 1, 3) + 0;  # Numeric conversion, removes leading zeros
```

---

## Example CSV File

```csv
Line1,Line2,Line3,Line4,line5,line6,line7,line8,line9,line10
"0067--  btg  --05-15-26","nSmith, John Q","a123 Main St$Springfield, MO 65801","t(417) 555-1234","hP.O. Box 456","p(417) 555-5678","dbtg","u12345678MBTS","b21714123456789","zjsmith@mbts.edu"
```

**Parsed Result:**
- patron_type: 67
- pcode1: "-"
- pcode2: "-"
- pcode3: "  " (2 spaces)
- home_library: "btg  " (btg + 2 spaces)
- patron_message_code: "-"
- patron_block_code: "-"
- patron_expiration_date: "05-15-26"
- name: "Smith, John Q"
- address: "123 Main St$Springfield, MO 65801"
- telephone: "(417) 555-1234"
- address2: "P.O. Box 456"
- telephone2: "(417) 555-5678"
- department: "btg"
- unique_id: "12345678MBTS"
- barcode: "21714123456789"
- email_address: "jsmith@mbts.edu"
- esid: "jsmith@mbts.edu" (from email)

---

## Error Handling
- **Try/Catch Blocks:** All substr operations wrapped in eval blocks
- **Warnings:** Printed to console if parsing fails
- **Graceful Degradation:** Patron created with empty fields if errors occur
- **BOM Handling:** Automatic, no manual intervention needed

---

## Duplicate Detection
- Uses fingerprinting with exact string comparison
- Checks against all previously parsed patrons
- Duplicates not added to output

---

## Notes
- **Unique Format:** Hybrid of fixed-length and tagged fields
- **Column Naming:** Inconsistent capitalization (Line1-Line4 vs line5-line10)
- **CSV Structure:** 10 columns always expected
- **Email as ESID:** Primary identifier is email address
- **UTF-8 Support:** BOM automatically handled
- **No NULL Sanitization:** Literal "NULL" strings not converted

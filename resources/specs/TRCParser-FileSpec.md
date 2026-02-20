# TRC Parser - File Specification

## Institution
**Three Rivers College (TRC)**

## Parser Class
`Parsers::TRCParser`

## Parent Class
Extends `ParserInterface` (independent implementation)

## File Format
**CSV (Comma-Separated Values)**

---

## Expected Column Headers

| Column Name | Required | Data Type | Description |
|-------------|----------|-----------|-------------|
| patronType | No | Text/Number | Patron classification (leading zeros removed) |
| text | No | Text (6+ chars) | Fixed-width packed data for PCODEs |
| expirationDate | No | Date | Patron expiration date |
| lastName | No | Text | Surname |
| firstName | No | Text | Given name |
| middleName | No | Text | Middle name |
| address | No | Text | Street address |
| cityStateZip | No | Text | City, state, and ZIP combined |
| username | No | Text | Unique login identifier |
| barcode | No | Text | Library barcode |
| emailAddress | No | Text | Email contact |
| esid | Yes | Text | External System ID (required) |

---

## Text Field Format (Fixed-Width Packed Data)

The `text` column contains fixed-position data:

```
Format: "clbtg0"
         ↑↑^^^^
         ││└─┬─┘
         │└──┼── pcode3 (3 chars): positions 2-5
         └───┼── pcode2 (1 char): position 1
             └── pcode1 (1 char): position 0
              home_library (5 chars): positions 5-10
```

| Position | Length | Field Name | Extraction |
|----------|--------|------------|------------|
| 0 | 1 | PCODE1 | `substr($text, 0, 1)` |
| 1 | 1 | PCODE2 | `substr($text, 1, 1)` |
| 2-4 | 3 | PCODE3 | `substr($text, 2, 3)` |
| 5-9 | 5 | Home Library | `substr($text, 5, 5)` |

**Example:**
```
text = "clbtg0"
→ pcode1: "c"
→ pcode2: "l"
→ pcode3: "btg"
→ home_library: "0" (only 1 char available, rest empty)
```

---

## Field Requirements

### Required Fields
- **esid** - Patron skipped if empty

### Optional Fields
- All other fields default to empty strings

---

## Special Processing

### Patron Type Transformation
Leading zeros removed via regex:
```perl
$patronType =~ s/^0+(\d+)$/$1/;
```

**Examples:**
```
"001" → "1"
"015" → "15"
"100" → "100"
```

### Name Construction
Combines name components with filtering:
```perl
$name = join(", ", grep {$_} ($lastName, $firstName, $middleName));
```

**Examples:**
```
lastName="Smith", firstName="John", middleName="Q"
→ "Smith, John, Q"

lastName="Jones", firstName="Mary", middleName=""
→ "Jones, Mary"
```

### Text Field Extraction
Uses substr() with default empty string:
```perl
$pcode1 = substr($text || "", 0, 1) || "";
$pcode2 = substr($text || "", 1, 1) || "";
$pcode3 = substr($text || "", 2, 3) || "";
$homeLibrary = substr($text || "", 5, 5) || "";
```

---

## Data Transformations

### Name Format
- Input: Separate lastName, firstName, middleName
- Output: "Last, First, Middle" (comma-separated)

### Address Handling
- address: Street address only
- address2: cityStateZip field

### Department Format
- Stored as JSON: `{}`

---

## Example CSV File

```csv
patronType,text,expirationDate,lastName,firstName,middleName,address,cityStateZip,username,barcode,emailAddress,esid
"015","clbtg0","05/15/2026","Smith","John","Q","123 Main St","Poplar Bluff, MO 63901","jsmith","2171412345","jsmith@trcc.edu","TRC12345"
```

**Parsed Result:**
- patron_type: "15" (leading zero removed)
- pcode1: "c"
- pcode2: "l"
- pcode3: "btg"
- home_library: "0" (only 1 char from text field)
- patron_expiration_date: "05/15/2026"
- name: "Smith, John, Q"
- address: "123 Main St"
- address2: "Poplar Bluff, MO 63901"
- unique_id: "jsmith"
- barcode: "2171412345"
- email_address: "jsmith@trcc.edu"
- esid: "TRC12345"

---

## Error Handling
- Missing text field: All PCODE/library fields default to ""
- Missing name components: Filtered out during join
- Missing esid: Patron skipped

---

## Notes
- **Unique Feature:** Packed positional data in `text` CSV field
- **Not Zero Line:** Different from Sierra format (uses CSV columns)
- **Patron Type:** Leading zeros always removed
- **Short text:** May not have all 10 characters, substr handles safely
- **No NULL Sanitization:** Literal "NULL" strings not converted

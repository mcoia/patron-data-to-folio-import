# KCKCC Parser - File Specification

## Institution
**Kansas City Kansas Community College (KCKCC)**

## Parser Class
`Parsers::KCKCCParser`

## Parent Class
Extends `SierraParser` (inherits all Sierra format handling)

## File Format
**Sierra Format** - Text-based patron records with fixed-position "zero line" and variable-length tagged fields

---

## File Structure

### Zero Line Format (Inherited from SierraParser)

Same as standard Sierra format - see SierraParser specification for complete details.

```
Format: "0101c-003clb  --01/31/24"
```

| Position | Length | Field Name | Description |
|----------|--------|------------|-------------|
| 0 | 1 | Field Code | Always '0' |
| 1-3 | 3 | Patron Type | Numeric code (000-255) |
| 4 | 1 | PCODE1 | Statistical code |
| 5 | 1 | PCODE2 | Statistical code |
| 6-8 | 3 | PCODE3 | Statistical code (000-255) |
| 9-13 | 5 | Home Library | 3-char code + 2 spaces |
| 14 | 1 | Patron Message Code | Trigger message display |
| 15 | 1 | Patron Block Code | Manual checkout block |
| 16-23 | 8 | Patron Expiration Date | mm-dd-yy format |

### Variable-Length Tagged Fields (Inherited)

| Tag | Field Name | Description |
|-----|------------|-------------|
| n | Name | Format: "Last, First Middle" |
| a | Address | Use '$' for line breaks |
| t | Telephone | No auto-formatting |
| h | Address2 | Secondary/permanent address |
| p | Telephone2 | Secondary phone |
| d | Department | Return address code |
| u | Unique ID | Institution ID + suffix |
| b | Barcode | Campus or library-issued |
| z | Email Address | Triggers email notices |
| x | Note | Free text (staff-only) |
| e | ESID | External System ID |
| s | Preferred Name | Display name |
| c | Custom Fields | XML format |

---

## Field Requirements

### Required Fields (Inherited from SierraParser)
- Patron Type
- ESID (External System ID)
- Unique ID (u tag)

### Optional Fields
- All other Sierra fields

---

## Special Processing

### Barcode Cleaning (afterParse)
KCKCC Parser performs unique post-processing:

**Purpose:** Remove institution suffix from Unique ID to create Barcode

**Algorithm:**
```perl
if ($patron->{unique_id}) {
    $patron->{barcode} = $patron->{unique_id} =~ s/(?i)KCKCC$//r;
}
```

**Behavior:**
- Searches for "KCKCC" suffix in unique_id (case-insensitive)
- Removes suffix if found
- Stores result as barcode
- Non-destructive (original unique_id preserved)

**Examples:**
```
Unique ID: "12345KCKCC"   → Barcode: "12345"
Unique ID: "12345kckcc"   → Barcode: "12345"
Unique ID: "12345"        → Barcode: "12345"
Unique ID: "12345ABC"     → Barcode: "12345ABC"
```

---

## Data Transformations

All standard Sierra transformations apply (inherited from parent):
- Patron Type: Numeric conversion
- Expiration Date: Flexible regex matching
- Name: Indexed format "Last, First Middle"
- Address: '$' indicates line breaks
- Department: XML parsing if present
- Custom Fields: XML-to-JSON conversion

**Plus KCKCC-specific:**
- Barcode: Derived from unique_id by removing "KCKCC" suffix

---

## Example Record

```
0101c-003clb  --01/31/24
nSmith, Jane
a123 Main St$Kansas City, KS 66101
t(913) 555-1234
dkckcc
u12345678KCKCC
zjsmith@kckcc.edu
e12345678
```

**After Processing:**
- unique_id: "12345678KCKCC"
- barcode: "12345678" (KCKCC suffix removed)

---

## Error Handling
- Inherits all Sierra error handling
- Barcode cleaning is safe: won't fail if no suffix exists
- Missing unique_id: barcode remains empty

---

## Notes
- **Primary Differentiator:** Barcode cleaning in afterParse
- **Inherits:** All Sierra parsing logic from parent class
- **Institution-Specific:** Removes "KCKCC" suffix from unique_id
- **Case-Insensitive:** Works with "KCKCC", "kckcc", "KcKcC", etc.

# Covenant Parser - File Specification

## Institution
**Covenant College**

## Parser Class
`Parsers::CovenantParser`

## Parent Class
Extends `SierraParser` (inherits all Sierra format handling)

## File Format
**Sierra Format** - Text-based patron records with fixed-position "zero line" and variable-length tagged fields

---

## File Structure

### Zero Line Format (Fixed-Length, 24+ Characters)

Each patron record begins with a "zero line" containing fixed-position fields:

```
Format: "0101c-003clb  --01/31/24"
```

| Position | Length | Field Name | Description | Example |
|----------|--------|------------|-------------|---------|
| 0 | 1 | Field Code | Always '0' | `0` |
| 1-3 | 3 | Patron Type | Numeric code (000-255) | `101` |
| 4 | 1 | PCODE1 | Statistical code | `c` or `-` |
| 5 | 1 | PCODE2 | Statistical code | `-` |
| 6-8 | 3 | PCODE3 | Statistical code (000-255) | `003` |
| 9-13 | 5 | Home Library | 3-char code + 2 spaces | `clb  ` |
| 14 | 1 | Patron Message Code | Trigger message display | `-` |
| 15 | 1 | Patron Block Code | Manual checkout block | `-` |
| 16-23 | 8 | Patron Expiration Date | mm-dd-yy format | `01/31/24` |

### Variable-Length Tagged Fields

Following the zero line, each field is on a separate line with a single-character tag:

| Tag | Field Name | Required | Description | Example |
|-----|------------|----------|-------------|---------|
| n | Name | Yes | Format: "Last, First Middle" | `nSmith, Jane` |
| a | Address | No | Use '$' for line breaks | `aP.O. Box 177$305B East Hall` |
| t | Telephone | No | No auto-formatting | `t(510) 555-1305` |
| h | Address2 | No | Secondary/permanent address | `h123 Hill St.$Oakland, CA 95155` |
| p | Telephone2 | No | Secondary phone | `p(510)444-1010` |
| d | Department | No | XML format with tags | `d<department>clb</department>` |
| u | Unique ID | Yes | Institution ID + alpha suffix | `u123456789CC` |
| b | Barcode | No | Campus or library-issued | `b2117102003159` |
| z | Email Address | No | Triggers email notices | `zjanesmith@campus.edu` |
| x | Note | No | Free text (staff-only) | `xSpecial handling required` |
| e | External System ID (ESID) | Yes | Required for matching | `e12345678` |
| s | Preferred Name | No | Display name | `sJane` |
| c | Custom Fields | No | XML format | `c<field name="status"><value>Active</value></field>` |

---

## Field Requirements

### Required Fields
- **Patron Type** (from zero line, positions 1-3)
- **ESID** (External System ID) - patron skipped if empty
- **Unique ID** (u tag) - used as record key
- **Name** (n tag)

### Optional Fields
- All PCODE fields (can be '-' or spaces if undefined)
- All address and contact fields
- Department
- Custom fields
- Preferred name
- Notes

---

## Special Processing

### Department Lookup (afterParse)
Covenant Parser performs additional processing after parsing:

1. **Fetches departments from Folio API** using tenant configuration
2. **Matches patron PCODE3** to department code in Folio
3. **Updates patron record** with matching department
4. **Sets JSON format**: `{department-name}` or `{}`  (empty if no match)
5. **Recalculates fingerprint** after department update

**Database Query:**
- Looks up department mappings from Folio
- Uses PCODE3 value to find matching department
- Logs warnings if API call fails

### Data Transformations
- **Patron Type:** Converted to numeric (removes leading zeros)
- **PCODE3:** Stored as-is (may have leading zeros)
- **Expiration Date:** Flexible regex: `\d{1,2}[\-\/\.]\d{1,2}[\-\/\.]\d{2,4}`
- **Name:** Stored in indexed format "Last, First Middle"
- **Address:** '$' character indicates line break
- **Department:** Parsed from XML `<department>` tags into JSON array
- **Custom Fields:** Parsed from XML format, converted to JSON

### Custom Fields Format
```xml
c<field name="status"><value>Active</value></field>
c<field name="type"><value>Student</value><value>Employee</value></field>
```

Converted to JSON (outer braces stripped):
```json
"status": ["Active"],
"type": ["Student", "Employee"]
```

---

## Example Record

```
0101c-003clb  --01/31/24
nSmith, Jane
aP.O. Box 177$305B East Hall
t(510) 555-1305
h123 Hill St.$Oakland, CA 95155
p(510)444-1010
d<department>clb</department>
u123456789CC
b2117102003159
zjanesmith@campus.edu
xActive student
e12345678
sJane
c<field name="status"><value>Active</value></field>
```

---

## Error Handling
- Patron Type parsing failures mark patron as unparsed
- Department API failures logged as warnings
- Missing ESID causes patron to be skipped
- Invalid XML in custom fields may cause parsing errors

---

## Notes
- Inherits full Sierra parsing logic from parent class
- Primary differentiator: Department lookup via Folio API
- Custom fields use XML-to-JSON conversion
- Department field requires database connection to Folio

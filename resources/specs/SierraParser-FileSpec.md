# Sierra Parser - File Specification

## Institution
**Not Institution-Specific** - Base parser used by multiple institutions

## Parser Class
`Parsers::SierraParser`

## Parent Class
Extends `ParserInterface` (base implementation)

## File Format
**Sierra Native Text Format** - Multi-line patron records in fixed-position Sierra format

**Note:** This is the base parser inherited by:
- CovenantParser
- KCKCCParser
- MissouriWesternParser
- TrumanParser

---

## File Structure

### Record Structure
Each patron record consists of:
1. **Zero Line** (required) - Fixed-position header with codes and dates
2. **Variable-Length Fields** (optional) - Tagged fields, one per line

### Record Delimiter
Empty line between patron records

---

## Zero Line Format (24 Characters Fixed)

```
Format: "0101c-003clb  --01/31/24"
         ^^^^^^^^^^^^^^^  ^^^^^^^^
         Codes (16 chars) Date (8)
```

| Position | Length | Field Name | Description | Values |
|----------|--------|------------|-------------|--------|
| 0 | 1 | Field Code | Record type indicator | Always `0` |
| 1-3 | 3 | Patron Type | Patron classification | `000` to `255` |
| 4 | 1 | PCODE1 | Statistical subdivision | Any char, `-` if undefined |
| 5 | 1 | PCODE2 | Statistical subdivision | Any char, `-` if undefined |
| 6-8 | 3 | PCODE3 | Statistical subdivision | `000` to `255`, spaces if undefined |
| 9-13 | 5 | Home Library | Location code | 3-char code + 2 spaces (e.g., `shb  `) |
| 14 | 1 | Patron Message Code | Triggers display message | Any char, `-` if undefined |
| 15 | 1 | Patron Block Code | Manual checkout block | Any char, `-` if undefined |
| 16-23 | 8 | Patron Expiration Date | Expiration date | `mm-dd-yy` format |

**Example:**
```
"0101c-003clb  --01/31/24"
 ↑   ↑     ↑    ↑      ↑
 │   │     │    │      └─ Expiration: 01/31/24
 │   │     │    └──────── Block Code: -
 │   │     └───────────── Message Code: -
 │   └─────────────────── Home Library: clb (+ 2 spaces)
 └─────────────────────── Field Code: 0
     Patron Type: 101
     PCODE1: c
     PCODE2: -
     PCODE3: 003
```

---

## Variable-Length Field Tags

Each field starts with a single-character tag on its own line:

| Tag | Field Name | Required | Format | Description |
|-----|------------|----------|--------|-------------|
| n | Name | Yes | "Last, First Middle" | Indexed format, displays as entered |
| a | Address | No | Use `$` for line break | Primary/local address |
| h | Address2 | No | Use `$` for line break | Secondary/permanent address |
| t | Telephone | No | No auto-formatting | Primary/local phone |
| p | Telephone2 | No | No auto-formatting | Secondary phone |
| d | Department | No | XML: `<department>name</department>` | Return address for INN-Reach |
| u | Unique ID | Yes | Number + Alpha suffix | Match key (e.g., `12345678CC`) |
| b | Barcode | No | Numeric or alphanumeric | Indexed, often campus ID |
| z | Email Address | No | Standard email format | Triggers email notices |
| x | Note | No | Free text (repeatable) | Staff-only, not visible to patron |
| e | External System ID (ESID) | Yes | Institution-specific | NEW - required for matching |
| s | Preferred Name | No | Display name | NEW - optional display name |
| c | Custom Fields | No | XML format | NEW - see format below |

---

## Field Formats

### Name (n tag)
```
nLast, First Middle
```
- Indexed format: "Last, First Middle"
- Displays exactly as entered (case preserved)

### Address (a, h tags)
```
aP.O. Box 177$305B East Hall
```
- `$` character indicates line break
- Will print on separate lines in notices

### Department (d tag)
```
d<department>shb</department><department>lib</department>
```
- XML format with `<department>` tags
- Can have multiple departments
- Parsed to JSON array: `["shb", "lib"]`

### Unique ID (u tag)
```
u12345678CC
```
- Patron identification number + alpha suffix
- Alpha suffix identifies institution (all caps, no spaces)
- Used as match key for updates
- Examples: `12345678CC`, `987654UU`

### Custom Fields (c tag)
```
c<field name="status"><value>Active</value></field>
c<field name="type"><value>Student</value><value>Employee</value></field>
```
- XML format with `<field name="">` tags
- Nested `<value>` tags for multiple values
- Parsed to JSON (outer braces stripped):
```json
"status": ["Active"],
"type": ["Student", "Employee"]
```

---

## Field Requirements

### Required Fields
- **Field Code** (0) - zero line must start with `0`
- **Patron Type** - must parse successfully (causes failure if malformed)
- **Unique ID** (u tag) - used as record key for updates
- **ESID** (e tag) - patron skipped if empty

### Optional Fields
- All PCODE fields (can be `-` or spaces)
- All variable-length fields except name, unique_id, and ESID
- Home Library (can be spaces)
- Message/Block codes (can be `-`)

---

## Special Processing

### Data Transformations

#### Patron Type
- Converted to numeric (removes leading zeros)
- Try/catch with regex fallback
```perl
$patronType = substr($data, 1, 3) + 0;  # "101" → 101
```

#### PCODE Fields
- Extracted via substr or regex
- Try/catch blocks for safety
- Defaults to empty string if extraction fails

#### Expiration Date
- Flexible regex matching supports multiple formats:
  - `mm-dd-yy`: "01-31-24"
  - `mm/dd/yyyy`: "01/31/2024"
  - `mm.dd.yy`: "01.31.24"
- Pattern: `\d{1,2}[\-\/\.]\d{1,2}[\-\/\.]\d{2,4}`

#### Department Parsing
```perl
# Extract all <department>...</department> tags
@departments = $data =~ /<department>([^<]+)<\/department>/g;
# Convert to JSON array
$department = '["' . join('","', @departments) . '"]';
```

#### Custom Fields Parsing
```perl
# Extract field name and values
while ($data =~ /<field name="([^"]+)">(.+?)<\/field>/g) {
    $fieldName = $1;
    @values = $fieldData =~ /<value>([^<]+)<\/value>/g;
    # Build JSON structure
}
```

---

## Example Complete Record

```
0101c-003shb  --12-31-25
nSmith, Jane Elizabeth
aP.O. Box 177$305B East Hall
t(510) 555-1305
h123 Hill St.$Oakland, CA 95155
p(510) 444-1010
d<department>shb</department>
u123456789UU
b2117102003159
zjanesmith@campus.edu
xActive student - honor roll
xRequires special accommodation
e123456789
sJane
c<field name="status"><value>Active</value></field>
c<field name="program"><value>Undergraduate</value><value>Honors</value></field>

```
*(Empty line marks end of record)*

---

## Error Handling

### Patron Type Parsing Failure
```
Marks patron as unparsed ($isParsed = 0)
Logs: "we failed! patron_type"
```

### PCODE Parsing Failures
```
Logs warning but continues
PCODE field set to empty string
```

### Missing ESID
```
Patron skipped entirely
Not added to parsed patron list
```

---

## Whitespace Handling
Zero line is cleaned before parsing:
```perl
$data =~ s/^\s*//g if ($data =~ /^0/);  # Strip leading whitespace
$data =~ s/\s*$//g if ($data =~ /^0/);  # Strip trailing whitespace
$data =~ s/\n//g if ($data =~ /^0/);    # Remove newlines
$data =~ s/\r//g if ($data =~ /^0/);    # Remove carriage returns
```

---

## Duplicate Detection
- Uses fingerprinting with regex pattern matching
- Checks against all previously parsed patrons
- Duplicates not added to output
```perl
push(@parsedPatrons, $patron)
    unless (grep /$patron->{fingerprint}/, map {$_->{fingerprint}} @parsedPatrons);
```

---

## Notes
- **Base Parser:** Inherited by multiple institution-specific parsers
- **MOBIUS Format:** Standard format for MOBIUS Consortium
- **Field Flexibility:** Can handle missing fields gracefully
- **XML Support:** Department and custom fields use XML-like syntax
- **Backwards Compatible:** ESID and preferred_name are new additions
- **No NULL Sanitization:** Literal "NULL" strings not converted

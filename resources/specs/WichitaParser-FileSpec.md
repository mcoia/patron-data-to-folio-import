# Wichita Parser - File Specification

## Institution
**Wichita State University**

## Parser Class
`Parsers::WichitaParser`

## Parent Class
Extends `ParserInterface` (independent implementation)

## File Format
**CSV (Comma-Separated Values)**

---

## Expected Column Headers

| Column Name | Required | Data Type | Description |
|-------------|----------|-----------|-------------|
| lastName | No | Text | Surname |
| firstName | No | Text | Given name |
| middleName | No | Text | Middle name/initial |
| address | No | Text | Street address |
| city | No | Text | City name |
| state | No | Text | State abbreviation |
| zip | No | Text | ZIP code |
| patronType | No | Text/Number | Patron classification |
| expirationDate | No | Date (ISO) | Patron expiration (YYYY-MM-DD) |
| phoneNumber | No | Text | Primary telephone |
| username | No | Text | Unique login identifier |
| barcode | No | Text | Library barcode |
| emailAddress | No | Text | Email contact |
| esid | Yes | Text | External System ID (required) |

---

## Field Requirements

### Required Fields
- **esid** - Patron skipped if empty

### Optional Fields
- All other fields default to empty strings

---

## Special Processing

### Name Construction
Builds "Last, First Middle" format with proper spacing:
```perl
my $fullName = $lastName;
if ($firstName) {
    $fullName .= ", $firstName";
    if ($middleName) {
        $fullName .= " $middleName";
    }
}
```

**Examples:**
```
lastName="Smith", firstName="John", middleName="Q"
→ "Smith, John Q"

lastName="Jones", firstName="Mary", middleName=""
→ "Jones, Mary"

lastName="Brown", firstName="", middleName=""
→ "Brown"
```

### Address Concatenation
Combines address components with space separation:
```perl
$address = join(" ", grep {$_ && $_ ne ''} ($addressLine, $city, $state, $zip));
```

**Examples:**
```
address="123 Main St", city="Wichita", state="KS", zip="67260"
→ "123 Main St Wichita KS 67260"

address="", city="Wichita", state="KS", zip=""
→ "Wichita KS"
```

### Date Format Conversion
Converts ISO format (YYYY-MM-DD) to MM-DD-YY:
```perl
if ($expirationDate =~ m{^(\d{4})-(\d{2})-(\d{2})$}) {
    my ($year, $month, $day) = ($1, $2, $3);
    $expirationDate = sprintf("%02d-%02d-%02d", $month, $day, $year % 100);
}
```

**Examples:**
```
"2026-05-15" → "05-15-26"
"2024-12-31" → "12-31-24"
"05/15/2026" → "05/15/2026" (not ISO, passed through)
```

### Whitespace Normalization
All text fields trimmed:
```perl
s/^\s+|\s+$//g  # Applied to:
- lastName, firstName, middleName
- address, city, state, zip
- patronType, expirationDate
- phoneNumber, username, barcode, emailAddress
```

---

## Data Transformations

### Name Format
- Input: Separate lastName, firstName, middleName fields
- Output: "Last, First Middle" with smart comma/space handling

### Address Format
- Input: Separate address, city, state, zip fields
- Output: Single concatenated string, empty fields filtered

### Date Format
- Input: ISO format (YYYY-MM-DD)
- Output: MM-DD-YY format
- Non-ISO dates: Passed through unchanged

### Department Format
- Stored as JSON: `{}`

---

## Example CSV File

```csv
lastName,firstName,middleName,address,city,state,zip,patronType,expirationDate,phoneNumber,username,barcode,emailAddress,esid
Smith,John,Q,123 Main St,Wichita,KS,67260,15,2026-05-15,3165551234,jsmith,21714123456,jsmith@wichita.edu,WSU12345
```

**Parsed Result:**
- name: "Smith, John Q"
- address: "123 Main St Wichita KS 67260"
- address2: ""
- patron_type: "15"
- patron_expiration_date: "05-15-26" (converted from 2026-05-15)
- telephone: "3165551234"
- unique_id: "jsmith"
- barcode: "21714123456"
- email_address: "jsmith@wichita.edu"
- esid: "WSU12345"

**Empty PCODE fields:**
- pcode1: ""
- pcode2: ""
- pcode3: ""
- home_library: ""

---

## Error Handling
- Missing name components: Handled gracefully (empty fields filtered)
- Missing address components: Empty fields filtered during join
- Non-ISO date format: Passed through unchanged
- Missing esid: Patron skipped

---

## Duplicate Detection
- Uses fingerprinting with exact string comparison
- Checks against all previously parsed patrons
- Duplicates not added to output

---

## Notes
- **No Zero Line:** Pure CSV format, no encoded Sierra data
- **Separate Address Fields:** Individual components joined into single address
- **Date Conversion:** Only parser that converts from ISO to MM-DD-YY
- **Whitespace Cleanup:** Comprehensive trimming on all fields
- **No PCODE Support:** No statistical codes (empty by default)
- **No NULL Sanitization:** Literal "NULL" strings not converted

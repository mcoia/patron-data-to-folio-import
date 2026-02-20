# Truman Parser - File Specification

## Institution
**Truman State University**

## Parser Class
`Parsers::TrumanParser`

## Parent Class
Extends `SierraParser` (inherits all Sierra format handling)

## File Format
**Sierra Format** - Text-based patron records (inherited from SierraParser)

---

## File Structure

### Zero Line Format (Inherited)
Standard Sierra 24-character format - see SierraParser specification

### Variable-Length Tagged Fields (Inherited)
All standard Sierra field tags supported

---

## Field Requirements

### Required Fields (Inherited)
- Patron Type
- ESID (External System ID)
- Unique ID

### Optional Fields (Inherited)
- All other Sierra fields

---

## Special Processing

### Custom Field Massaging (afterParse)

Truman Parser modifies custom field format in post-processing:

#### Transformation 1: Field Name Replacement
Replaces "Other Barcode 1" with "otherBarcode":
```perl
$patron->{custom_fields} =~ s/Other Barcode 1/otherBarcode/g;
```

**Before:**
```json
{
  "Other Barcode 1": ["12345"]
}
```

**After:**
```json
{
  "otherBarcode": ["12345"]
}
```

#### Transformation 2: Bracket Removal
Removes square brackets `[` and `]`:
```perl
$patron->{custom_fields} =~ s/\[//g;
$patron->{custom_fields} =~ s/\]//g;
```

**Before:**
```json
{
  "status": ["[Active]"]
}
```

**After:**
```json
{
  "status": ["Active"]
}
```

---

## Data Transformations

### Inherited from SierraParser
- All standard Sierra transformations apply
- Zero line parsing
- Tagged field extraction
- Department XML parsing
- Custom fields XML-to-JSON conversion

### Truman-Specific
- Custom field name normalization
- Bracket cleanup in custom field values

---

## Example Record

**Input (Sierra Format):**
```
0101c-003tru  --12-31-25
nSmith, Jane
u12345678TU
zjsmith@truman.edu
e12345678
c<field name="Other Barcode 1"><value>[ABC123]</value></field>
c<field name="status"><value>[Active]</value></field>
```

**After Sierra Parsing:**
```json
custom_fields: {
  "Other Barcode 1": ["[ABC123]"],
  "status": ["[Active]"]
}
```

**After Truman afterParse:**
```json
custom_fields: {
  "otherBarcode": ["ABC123"],
  "status": ["Active"]
}
```

---

## Error Handling
- Inherits all Sierra error handling
- Custom field modifications are safe (regex won't fail if pattern not found)

---

## Notes
- **Primary Differentiator:** Custom field cleanup in afterParse
- **Inherits:** All Sierra parsing logic from parent class
- **Institution-Specific:** Normalizes "Other Barcode 1" field name
- **Cosmetic Changes:** Removes decorative brackets from values

# Missouri Western Parser - File Specification

## Institution
**Missouri Western State University**

## Parser Class
`Parsers::MissouriWesternParser`

## Parent Class
Extends `SierraParser` (inherits all Sierra format handling)

## File Format
**Sierra Format** - Text-based patron records (inherited from SierraParser)

---

## File Structure

### Zero Line Format (Inherited)
Same as standard Sierra format - see SierraParser specification.

### Variable-Length Tagged Fields (Inherited)
All standard Sierra field tags supported (n, a, t, h, p, d, u, b, z, x, e, s, c)

---

## Field Requirements

### Required Fields (Inherited)
- Patron Type
- ESID (External System ID)
- Unique ID

### Additional Requirements
- **PCODE2 Mappings:** Must exist in database table `patron_import.pcode2_mapping`
- **PCODE3 Mappings:** Must exist in database table `patron_import.pcode3_mapping`

---

## Special Processing

### Custom Field Mappings (afterParse)

Missouri Western Parser performs database lookups to map PCODE values to custom fields:

#### PCODE2 → Class Level Mapping
**Source:** Database table `patron_import.pcode2_mapping`

**Query:**
```sql
SELECT pcode2, pcode2_value
FROM patron_import.pcode2_mapping
WHERE institution_id = ?
```

**Behavior:**
- Maps PCODE2 value to descriptive class level
- Stored in patron custom_fields as `classlevel`
- Example: PCODE2="F" → classlevel="Freshman"

#### PCODE3 → Department Mapping
**Source:** Database table `patron_import.pcode3_mapping`

**Query:**
```sql
SELECT pcode3, pcode3_value
FROM patron_import.pcode3_mapping
WHERE institution_id = ?
```

**Behavior:**
- Normalizes PCODE3 (removes leading zeros)
- Maps to department name
- Stored in patron department field (overwriting original)
- Example: PCODE3="047" → normalized to "47" → department="Business"

### Processing Steps
1. **Load Mappings:** Fetch all mappings for institution from database
2. **Normalize PCODE3:** Remove leading zeros
   ```perl
   $pcode3 =~ s/^0+(\d+)$/$1/;  # "047" → "47"
   ```
3. **Lookup Values:** Match PCODE2/PCODE3 to database values
4. **Build Custom Fields:**
   ```json
   {
     "classlevel": ["Freshman"]
   }
   ```
5. **Update Department:** Replace with mapped value
6. **Recalculate Fingerprint:** After custom field updates

---

## Custom Fields Format

### Structure
```json
{
  "classlevel": ["<mapped_value>"]
}
```

### Example
**Input:**
- PCODE2: "F"
- PCODE3: "047"

**Database Mappings:**
- PCODE2 "F" → "Freshman"
- PCODE3 "47" → "Business" (after normalization)

**Output:**
```json
patron->{custom_fields} = '{"classlevel":["Freshman"]}'
patron->{department} = "Business"
```

---

## Data Transformations

### Inherited from SierraParser
- All standard Sierra transformations apply

### Missouri Western-Specific
1. **PCODE3 Normalization:**
   - Leading zeros removed
   - "047" → "47"
   - "003" → "3"
   - "100" → "100" (no leading zeros)

2. **Custom Fields:**
   - PCODE2 mapped to classlevel
   - Serialized to JSON format
   - Outer braces included

3. **Department Override:**
   - Original department value replaced
   - Uses PCODE3 mapping from database

---

## Database Schema

### pcode2_mapping Table
```sql
CREATE TABLE patron_import.pcode2_mapping (
    institution_id INTEGER,
    pcode2 VARCHAR(1),
    pcode2_value TEXT
);
```

**Example Data:**
```
institution_id | pcode2 | pcode2_value
14             | F      | Freshman
14             | S      | Sophomore
14             | J      | Junior
14             | R      | Senior
14             | G      | Graduate
```

### pcode3_mapping Table
```sql
CREATE TABLE patron_import.pcode3_mapping (
    institution_id INTEGER,
    pcode3 VARCHAR(3),
    pcode3_value TEXT
);
```

**Example Data:**
```
institution_id | pcode3 | pcode3_value
14             | 47     | Business
14             | 3      | Art
14             | 100    | Nursing
```

---

## Example Record Processing

**Input Record:**
```
0101FS047mwsu --01/31/24
nSmith, Jane
doriginal_dept
u12345678MW
zjsmith@missouriwestern.edu
e12345678
```

**After Parsing (from parent):**
- patron_type: 101
- pcode1: "F"
- pcode2: "S"
- pcode3: "047"
- home_library: "mwsu "
- department: "original_dept"

**After afterParse (Missouri Western):**
- pcode3: "47" (normalized)
- custom_fields: `{"classlevel":["Sophomore"]}`
- department: "Business" (overwritten)

---

## Error Handling
- Missing database mappings: Logged as warnings
- Database connection failures: Logged, processing continues
- Unmapped PCODE values: Custom fields/department remain empty
- Fingerprint recalculated even if mappings fail

---

## Logging
```
Loaded X PCODE2 mappings for institution Y
Loaded X PCODE3 mappings for institution Y
ERROR loading PCODE2/PCODE3 mappings: <error message>
```

---

## Notes
- **Database Dependency:** Requires access to patron_import schema
- **Institution-Specific:** Mappings are per-institution
- **Normalization:** PCODE3 leading zeros always removed
- **Override Behavior:** Department field completely replaced
- **Custom Fields:** Only classlevel currently mapped from PCODE2
- **Inherits:** All Sierra parsing logic and field formats from parent

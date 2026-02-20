# Stephens Parser - File Specification

## Institution
**Stephens College**

## Parser Class
`Parsers::StephensParser`

## Parent Class
Extends `ParserInterface` (independent implementation)

## File Format
**CSV or Excel (XLSX)** - Auto-detects based on file extension

---

## Expected Column Headers

| Column Name | Required | Data Type | Description |
|-------------|----------|-----------|-------------|
| fullname | Yes | Text | Full name in "Last, First Middle" format |
| PTYPE & Expiration | Yes | Text | Sierra zero line format |
| address | No | Text | Primary address (use `$` for line break) |
| mobilephone | No | Text | Primary telephone |
| uniqueid | No | Text | Unique login ID |
| Barcode | No | Text | Library barcode |
| emailaddress | No | Text | Email address |
| externalID | No | Text | External System ID |

**Alternative Column Names:**
- `PTYPE &amp; Expiration` → Handles XML entity encoding

---

## Zero Line Format (Standard Sierra)

**Example:** `0061--000ste  --05/17/2026`

### Format: Standard Sierra Positions 0-15 + Flexible Date

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
| 16+ | varies | Expiration Date | Flexible format (mm/dd/yyyy or mm-dd-yy) |

**Detection:** Generic `^0` check (no hybrid format detection like StateTech)

---

## Field Requirements

### Required Fields
- **fullname** - Name parsing
- **PTYPE & Expiration** - Zero line
- **ESID** - From externalID or ESID builder

### Optional Fields
- All others with fallbacks

---

## Special Processing

### Name Parsing
Same as StateTechParser:
```
"Last, First Middle" → Components → Rejoined
```

### Address Parsing
```
"Street$City, State ZIP" → address + address2
```

### Field Priority
```perl
unique_id: uniqueid → emailaddress
zero_line: "PTYPE & Expiration" → "PTYPE &amp; Expiration"
```

---

## Data Transformations

### Zero Line Parsing
Uses substr on standard Sierra positions 0-15:
```perl
$patronType = substr($zeroLine, 1, 3) + 0;
$pcode1 = substr($zeroLine, 4, 1);
$pcode2 = substr($zeroLine, 5, 1);
$pcode3 = substr($zeroLine, 6, 3);
$homeLibrary = substr($zeroLine, 9, 5);
$patronMessageCode = substr($zeroLine, 14, 1);
$patronBlockCode = substr($zeroLine, 15, 1);
($expirationDate) = $zeroLine =~ /(\d{1,2}[\-\/\.]\d{1,2}[\-\/\.]\d{2,4})\s*$/;
```

### Differences from StateTech
- ❌ No hybrid format detection (`^0\d{3}l`)
- ❌ No NULL string sanitization
- ✅ Same substr positions
- ✅ Same date regex

---

## Example CSV File

```csv
fullname,PTYPE & Expiration,address,mobilephone,uniqueid,externalID,emailaddress,Barcode
"Smith, Jane","0061--000ste  --05/17/2026","123 Main St$Columbia, MO 65201","5735551234","12345678SC","jsmith@stephens.edu","jsmith@stephens.edu","123456"
```

---

## Notes
- **Similar to StateTech:** Uses same parsing logic but simpler
- **No Hybrid Detection:** Generic zero line matching only
- **No NULL Sanitization:** Literal "NULL" strings not handled
- **XML Entity Handling:** Supports `&amp;` in header names
- **Dual Format Support:** CSV and XLSX

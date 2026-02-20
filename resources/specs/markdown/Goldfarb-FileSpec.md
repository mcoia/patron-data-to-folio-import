# Goldfarb Library
## Patron Data File Specification

**Parser:** GoldfarbParser
**File Formats Supported:** Excel (.xlsx) or CSV (.csv)
**Last Updated:** January 2026
**Contact:** MOBIUS Consortium Office

---

## Overview

Goldfarb Library uses a **direct column mapping format** (NO Sierra zero-line encoding). Each patron field has its own dedicated column in the file.

**Key Characteristics:**
- No zero-line format - uses individual columns for each field
- Separate first/last name columns
- Supports both campus and home addresses (campus preferred)
- Supports both Excel and CSV files

---

## File Format Requirements

### Character Encoding
- **Excel:** UTF-8 (automatic)
- **CSV:** UTF-8

### Structure
- **Row 1:** Column headers (exact spelling required - see note about "Libray" typo)
- **Row 2+:** Patron data

---

## Column Headers

**IMPORTANT:** Column names are case-sensitive and must match exactly, including the intentional typo in "Home Libray".

### Name Columns
| Column Name | Required | Description | Example |
|------------|----------|-------------|---------|
| `Last Name` | **Yes** | Patron last name | `Smith` |
| `First Name` | **Yes** | Patron first name | `John` |
| `Middle Initial` | No | Middle name or initial | `A` or `Alan` |

### Campus Address Columns (Preferred)
| Column Name | Required | Description | Example |
|------------|----------|-------------|---------|
| `Campus Address` | No | Campus street address | `100 University Hall` |
| `City` | No | Campus city | `Springfield` |
| `State` | No | Campus state | `MO` |
| `Zip` | No | Campus zip code | `65801` |

### Home Address Columns (Fallback)
| Column Name | Required | Description | Example |
|------------|----------|-------------|---------|
| `Home Address` | No | Home street address | `123 Main Street` |
| `City_1` | No | Home city | `Jefferson City` |
| `State_1` | No | Home state | `MO` |
| `Zip_1` | No | Home zip code | `65109` |

### Other Columns
| Column Name | Required | Description | Example |
|------------|----------|-------------|---------|
| `Patron Type` | No | Patron type designation | `Student` or `Faculty` |
| `Expiration Date` | No | Patron expiration date | `05/17/2026` |
| `Telephone Number` | No | Primary phone number | `573-123-4567` |
| `Unique ID Number` | No | Unique identifier | `12345678` |
| `University ID` | No | University ID (becomes ESID) | `jsmith@university.edu` |
| `Barcode` | No | Patron barcode | `87654321` |
| `E-mail Address` | **Yes** | Email address | `john.smith@university.edu` |
| `Note` | No | Patron note | `Graduate student` |
| `Home Libray` | No | **NOTE THE TYPO:** Must be "Libray" not "Library" | `goldfarb` |
| `User Principal Name (UPN)` | No | UPN (not currently used) | `jsmith@domain.edu` |

**CRITICAL NOTE:** The column name `Home Libray` contains an intentional typo ("Libray" instead of "Library"). This **must** be preserved for the parser to work correctly.

---

## Address Handling Logic

The parser uses campus address if available, otherwise falls back to home address:

1. **If campus address fields have any data:** Uses campus address components
2. **If campus address is empty:** Uses home address components
3. **Combined into single address field:** All components joined with spaces

**Example Processing:**
- Campus: `100 University Hall` + `Springfield` + `MO` + `65801` → `100 University Hall Springfield MO 65801`
- Home: `123 Main Street` + `Jefferson City` + `MO` + `65109` → `123 Main Street Jefferson City MO 65109`

---

## Sample Data File

### Excel Format Example

| Last Name | First Name | Middle Initial | Campus Address | City | State | Zip | Patron Type | Expiration Date | Telephone Number | Unique ID Number | University ID | Barcode | E-mail Address | Home Libray |
|-----------|------------|----------------|----------------|------|-------|-----|-------------|-----------------|------------------|------------------|---------------|---------|----------------|-------------|
| Smith | John | A | 100 University Hall | Springfield | MO | 65801 | Student | 05/17/2026 | 573-123-4567 | 12345678 | jsmith@univ.edu | 87654321 | john.smith@univ.edu | goldfarb |
| Doe | Jane | Marie | 200 Campus Dr | Springfield | MO | 65801 | Faculty | 12/31/2026 | 573-987-6543 | 23456789 | jdoe@univ.edu | 98765432 | jane.doe@univ.edu | goldfarb |
| Johnson | Robert |  |  |  |  |  | Staff | 06/30/2025 | 573-555-1234 | 34567890 | rjohnson@univ.edu | 11223344 | robert.johnson@univ.edu | goldfarb |

*Note: Robert Johnson has no campus address, so home address would be used (not shown in example)*

### CSV Format Example

```csv
Last Name,First Name,Middle Initial,Campus Address,City,State,Zip,Home Address,City_1,State_1,Zip_1,Patron Type,Expiration Date,Telephone Number,Unique ID Number,University ID,Barcode,E-mail Address,Note,Home Libray,User Principal Name (UPN)
Smith,John,A,100 University Hall,Springfield,MO,65801,,,,, Student,05/17/2026,573-123-4567,12345678,jsmith@univ.edu,87654321,john.smith@univ.edu,,goldfarb,jsmith@domain.edu
Doe,Jane,Marie,200 Campus Dr,Springfield,MO,65801,,,,,Faculty,12/31/2026,573-987-6543,23456789,jdoe@univ.edu,98765432,jane.doe@univ.edu,,goldfarb,jdoe@domain.edu
Johnson,Robert,,,,,,"456 Oak St","Jefferson City",MO,65109,Staff,06/30/2025,573-555-1234,34567890,rjohnson@univ.edu,11223344,robert.johnson@univ.edu,,goldfarb,rjohnson@domain.edu
```

---

## Name Assembly

Names are assembled into "Last, First Middle" format:
- `Last Name` + `, ` + `First Name` + ` ` + `Middle Initial`
- Example: `Smith` + `, ` + `John` + ` ` + `A` → `Smith, John A`
- If no middle initial: `Doe, Jane`

---

## Validation Checklist

### Required Fields
- ☑ Every row has `Last Name` and `First Name`
- ☑ Every row has `E-mail Address`

### Format Validation
- ☑ Column header `Home Libray` spelled with typo (not "Library")
- ☑ Excel file is .xlsx format
- ☑ CSV file is UTF-8 encoded

### Data Quality
- ☑ Email addresses are valid format
- ☑ Either campus address OR home address provided
- ☑ No duplicate patron records

---

## Common Errors

### "Column 'Home Library' not found"
**Cause:** Used correct spelling "Library" instead of typo "Libray"
**Fix:** Change column header to `Home Libray` (with typo)

### "Missing name components"
**Cause:** Empty Last Name or First Name fields
**Fix:** Ensure both Last Name and First Name are populated

### "No address found"
**Cause:** Both campus and home address fields are empty
**Fix:** Provide either campus address OR home address

---

## File Submission

1. Save as `.xlsx` (Excel) or `.csv` (CSV) format
2. Name file: `YYYY-MM-DD-Goldfarb-Patrons.xlsx`
3. Submit via MOBIUS secure file transfer

---

## Support

**MOBIUS Consortium Office**
Email: support@mobiusconsortium.org

---

**Document Version:** 1.0
**Parser Version:** GoldfarbParser.pm (2025-01)

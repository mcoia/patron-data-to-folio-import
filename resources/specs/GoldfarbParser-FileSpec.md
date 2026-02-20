# Goldfarb Parser - File Specification

## Institution
**Goldfarb School of Nursing at Barnes-Jewish College**

## Parser Class
`Parsers::GoldfarbParser`

## Parent Class
Extends `ParserInterface` (independent implementation)

## File Format
**CSV or Excel (XLSX)** - Auto-detects based on file extension
- `.xlsx` → Excel 2007+ format
- `.csv` or other → CSV format

---

## File Structure

### CSV/Excel Column Headers

| Column Name | Required | Data Type | Description | Example |
|-------------|----------|-----------|-------------|---------|
| Last Name | Yes | Text | Patron surname | `Smith` |
| First Name | Yes | Text | Patron given name | `John` |
| Middle Initial | No | Text | Middle name or initial | `Q` |
| Campus Address | No | Text | Primary/campus street address | `123 Campus Dr` |
| City | No | Text | Campus city | `St. Louis` |
| State | No | Text | Campus state | `MO` |
| Zip | No | Text | Campus ZIP code | `63110` |
| Home Address | No | Text | Secondary/permanent street address | `456 Home St` |
| City_1 | No | Text | Home city | `Springfield` |
| State_1 | No | Text | Home state | `IL` |
| Zip_1 | No | Text | Home ZIP code | `62701` |
| Patron Type | No | Text | Patron classification | `Student` |
| Expiration Date | No | Date | Patron expiration | `12/31/2026` |
| Telephone Number | No | Text | Primary phone | `(314) 555-1234` |
| Unique ID Number | No | Text | Local identifier | `U12345678` |
| University ID | No | Text | Becomes ESID (required) | `BJC00123456` |
| Barcode | No | Text | Library barcode | `21714123456789` |
| E-mail Address | No | Email | Email contact | `jsmith@bjc.edu` |
| Note | No | Text | Free text note | `Special handling` |
| Home Libray | No | Text | Home library code (note typo) | `bjc` |
| User Principal Name (UPN) | No | Text | Network login | `jsmith@campus.bjc.edu` |

**Note:** Column header contains typo "Libray" instead of "Library" - parser expects this spelling.

---

## Field Requirements

### Required Fields
- **Last Name** - Must be present for valid patron
- **First Name** - Must be present for valid patron
- **University ID** - Becomes ESID; patron skipped if empty

### Optional Fields
- All other fields have defaults to empty strings
- Address fields use fallback logic (see below)

---

## Special Processing

### Name Construction
Names are built in "Last, First Middle" format:
```
Last Name: "Smith"
First Name: "John"
Middle Initial: "Q"
→ Result: "Smith, John Q"
```

- Whitespace trimmed from all components
- Middle initial only added if present
- Components filtered for empty values

### Address Fallback Logic
**Priority:** Campus address is preferred, home address is fallback

**Campus Address Components:**
- Campus Address
- City
- State
- Zip

**Home Address Components:**
- Home Address
- City_1
- State_1
- Zip_1

**Logic:**
1. If ANY campus address component exists → use campus address
2. Else if ANY home address component exists → use home address
3. Else → empty address

**Concatenation:**
```
address = join(" ", filter_empty(street, city, state, zip))
```

### ESID Assignment
**Priority Order:**
1. `University ID` field (primary source)
2. ESID builder if University ID is empty
3. Patron skipped if ESID remains empty

---

## Data Transformations

### Name Format
- Input: Separate Last, First, Middle fields
- Output: "Last, First Middle" indexed format
- All components trimmed of whitespace

### Address Format
- Input: Separate address components
- Output: Single concatenated string with spaces
- Uses fallback logic (campus → home)

### Date Format
- Input: As provided in CSV/Excel
- Output: Passed through as-is
- No format conversion

---

## Example CSV Row

```csv
Last Name,First Name,Middle Initial,Campus Address,City,State,Zip,Home Address,City_1,State_1,Zip_1,Patron Type,Expiration Date,Telephone Number,Unique ID Number,University ID,Barcode,E-mail Address,Note,Home Libray,User Principal Name (UPN)
Smith,John,Q,123 Campus Dr,St. Louis,MO,63110,,,,,Student,12/31/2026,(314) 555-1234,U12345678,BJC00123456,21714123456789,jsmith@bjc.edu,Active student,bjc,jsmith@campus.bjc.edu
```

**Parsed Result:**
- Name: "Smith, John Q"
- Address: "123 Campus Dr St. Louis MO 63110"
- ESID: "BJC00123456"
- Barcode: "21714123456789"

---

## Example Excel File

**Headers (Row 1):**
```
| Last Name | First Name | Middle Initial | Campus Address | ... |
```

**Data (Row 2+):**
```
| Smith | John | Q | 123 Campus Dr | ... |
| Jones | Mary |   | 456 Student Ln | ... |
```

---

## Error Handling
- Missing Last/First Name: Creates empty name field
- Missing University ID: Patron skipped entirely
- Empty address components: Uses fallback or empty
- XML entities in Excel: Handled (`&amp;` → `&`)

---

## Duplicate Detection
- Uses fingerprinting with exact string comparison
- Compares against all previously parsed patrons
- Duplicate patrons not added to output

---

## Notes
- **Different Data Model:** Does not use Sierra zero line format
- **Direct field mapping:** Each data point is a separate column
- **Address flexibility:** Supports both campus and home addresses
- **CSV Header Typo:** "Home Libray" is expected (not "Library")
- **No NULL Sanitization:** Literal "NULL" strings not converted to empty

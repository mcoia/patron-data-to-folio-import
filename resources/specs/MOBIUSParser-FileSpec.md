# MOBIUS Parser - File Specification

## File Format
**CSV or TSV** - Auto-detects based on higher occurances of either commas or tabs
- `.tsv` → Tab Delimited (preferred)
- `.csv` or comma Delimited

---

## File Structure

### Column Headers

| Column Name | Required | Data Type | Description | Example |
|-------------|----------|-----------|-------------|---------|
| unique_id | Yes | Text | Patron's unique ID | `00000001LIB` |
| esid | Yes | Text | External ID | `0000000001LIB` |
| patron_type | Yes | Text | FOLIO "patron group" | `LIB Student` |
| email | No | Text | Email address | `example@example.com` |
| barcode | No | Text | Patron Barcode | `1234567890` |
| lastname | No | Text | Lastname | `Smith` |
| firstname | No | Text | Fastname | `Susan` |
| middlename | No | Text | Middlename | `Anthony` |
| preferredfirstname | No | Text | Preferred Name | `Sue` |
| pronouns | No | Text | Pronouns | `She/Her` |
| address1_line1 | No | Text | Address1: line1 | `123 Street Ave.` |
| address1_line2 | No | Text | Address1: line2 | `Apartment #1` |
| address1_city | No | Text | Address1: City | `Metropolis` |
| address1_state | No | Text | Address1: State | `MO` |
| address1_zip | No | Text | Address1: Zip | `12345` |
| address2_line1 | No | Text | Address2: line1 | `123 Home Street` |
| address2_line2 | No | Text | Address2: line2 | `Grandma's door` |
| address2_city | No | Text | Address2: City | `Metropolis` |
| address2_state | No | Text | Address2: State | `MO` |
| address2_zip | No | Text | Address2: Zip | `12345` |
| phone | No | Text | Patron Phone | `123-456-7890` |
| mobilephone | No | Text | Patron Mobile Phone | `123-456-7890` |
| enrollmentdate | No | Date | Patron Enrollment Date (MM/DD/YYYY) | `12/31/2021` |
| expirationdate | No | Date | Patron Expiration Date (MM/DD/YYYY) | `12/31/2030` |
| dateofbirth | No | Date | Patron DOB (MM/DD/YYYY) | `12/31/1996` |
| department | No | Text | List of Departments $ delimited | `Faculty$General Business$Department 3` |
| custom_fields | No | Text | Key value pairs JSON | `{"key1": "value1", "key1": "value2", "key2": "value1"}` |

**The first line needs to contain the column headings**

**Please include the column headers exactly as they are in the table above**


---


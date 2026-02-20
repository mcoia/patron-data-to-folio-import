# MOBIUS Patron Data File Specifications
## Index of All Parser Specifications

**Last Updated:** January 2026
**Contact:** MOBIUS Consortium Office

---

## Overview

This directory contains file format specifications for all MOBIUS member libraries using automated patron data loads. Each specification document describes the exact file format, column headers, and data requirements for that institution's parser.

**Total Parsers:** 10
**Total Specifications:** 10 PDF documents

---

## Quick Reference Guide

### By File Format

#### Excel (.xlsx) or CSV Formats
- **State Technical College of Missouri** - Hybrid Sierra zero-line format
- **Stephens College** - Sierra zero-line format with XML entity handling
- **Goldfarb Library** - Direct column mapping (no zero-line)

#### CSV Only Formats
- **Midwestern Baptist Theological Seminary (MBTS)** - Fixed-length Line1 + tagged fields
- **Wichita State University** - Direct column mapping with date conversion
- **Three Rivers College** - CSV with packed PCODE data in 'text' field

#### Sierra Text File Image (Format 3)
- **Truman State University** - Standard Sierra + custom barcode field
- **Covenant College** - Standard Sierra + API department mapping
- **Kansas City Kansas Community College (KCKCC)** - Standard Sierra + barcode extraction
- **Missouri Western State University** - Standard Sierra + database PCODE mapping

---

## Detailed Parser Index

### 1. State Technical College of Missouri
**Specification:** `StateTech-FileSpec.pdf`
**Format:** Excel (.xlsx) or CSV (.csv)
**Key Features:**
- Hybrid Sierra zero-line format in `PTYPE & Expiration` column
- Extended date format support (mm/dd/yyyy)
- NULL string sanitization
- Fallback column names supported

**Use this if:** Your institution exports patron data in Excel/CSV with Sierra-encoded zero-line metadata

**Critical Field:** `PTYPE & Expiration` containing `0061l-000lsb  --05/17/2026` format

---

### 2. Stephens College
**Specification:** `Stephens-FileSpec.pdf`
**Format:** Excel (.xlsx) or CSV (.csv)
**Key Features:**
- Sierra zero-line format in `PTYPE & Expiration` column
- Handles XML entity encoding (&amp; → &)
- Similar to State Tech but different column names

**Use this if:** Your institution uses Sierra zero-line format with potential XML encoding in headers

**Critical Field:** `PTYPE & Expiration` or `PTYPE &amp; Expiration`

---

### 3. Goldfarb Library
**Specification:** `Goldfarb-FileSpec.pdf`
**Format:** Excel (.xlsx) or CSV (.csv)
**Key Features:**
- Direct column mapping (NO zero-line format)
- Separate first/last/middle name columns
- Campus and home address options
- Note: Column header "Home Libray" contains intentional typo

**Use this if:** Your institution exports patron data with individual columns for each field (not Sierra format)

**Critical Columns:** `Last Name`, `First Name`, `E-mail Address`

---

### 4. Midwestern Baptist Theological Seminary (MBTS)
**Specification:** `MBTS-FileSpec.pdf`
**Format:** CSV (.csv) only (Excel NOT supported)
**Key Features:**
- Specialized multi-column format
- Line1: 26-character fixed-length zero-line
- Line2-Line10: Tagged fields (tag + data)
- Mixed case column headers (Line1-4 uppercase, line5-10 lowercase)
- UTF-8 BOM handling
- ESID set from email address

**Use this if:** Your institution exports multi-column CSV with Line1-Line10 format

**Critical Fields:** `Line1` (26 chars), `Line2` (name), `line10` (email)

---

### 5. Wichita State University
**Specification:** `Wichita-FileSpec.pdf`
**Format:** CSV (.csv) only (Excel NOT supported)
**Key Features:**
- Direct column mapping (NO zero-line)
- Separate name component columns
- Separate address component columns
- Date format auto-conversion (YYYY-MM-DD → MM-DD-YY)
- ESID from CSV column (NO fallback)

**Use this if:** Your institution exports CSV with separate columns and ISO date format

**Critical Fields:** `lastName`, `firstName`, `expirationDate` (YYYY-MM-DD), `esid`

---

### 6. Three Rivers College (TRC)
**Specification:** `TRC-FileSpec.pdf`
**Format:** CSV (.csv) only (Excel NOT supported)
**Key Features:**
- Hybrid CSV format
- Special `text` field containing 11-character packed PCODE/library data
- Separate name columns
- Patron type leading zero stripping

**Use this if:** Your institution uses a `text` field to encode PCODE and library data

**Critical Field:** `text` containing `l-000trcol` format (11 characters)

---

### 7. Truman State University
**Specification:** `Truman-FileSpec.pdf`
**Format:** Sierra Text File Image (Format 3)
**Key Features:**
- Standard Sierra format
- 24-character zero-line
- Variable-length tagged fields
- Optional "Other Barcode 1" custom field support

**Use this if:** Your institution exports standard Sierra Text File Image format

**Critical:** Zero line must be exactly 24 characters

**Reference:** See `resources/patron_batchloading.txt` for complete Sierra format documentation

---

### 8. Covenant College
**Specification:** `Covenant-FileSpec.pdf`
**Format:** Sierra Text File Image (Format 3)
**Key Features:**
- Standard Sierra format
- 24-character zero-line
- PCODE3 automatically mapped to department names via FOLIO API
- Requires coordination with MOBIUS for department mapping

**Use this if:** Your institution exports standard Sierra format with PCODE3-based department classification

**Critical:** PCODE3 values in zero-line must match FOLIO department codes

**Reference:** See `resources/patron_batchloading.txt` for complete Sierra format documentation

---

### 9. Kansas City Kansas Community College (KCKCC)
**Specification:** `KCKCC-FileSpec.pdf`
**Format:** Sierra Text File Image (Format 3)
**Key Features:**
- Standard Sierra format
- 24-character zero-line
- Barcode automatically extracted from unique_id (removes "KCKCC" suffix)
- Barcode field optional (can be auto-generated)

**Use this if:** Your institution exports standard Sierra format and embeds barcode in unique_id

**Critical:** Unique IDs must end with "KCKCC" suffix

**Reference:** See `resources/patron_batchloading.txt` for complete Sierra format documentation

---

### 10. Missouri Western State University
**Specification:** `MissouriWestern-FileSpec.pdf`
**Format:** Sierra Text File Image (Format 3)
**Key Features:**
- Standard Sierra format
- 24-character zero-line
- PCODE2 mapped to class level custom field (database-driven)
- PCODE3 mapped to department field (database-driven)
- PCODE3 leading zeros stripped before lookup
- Requires coordination with MOBIUS for PCODE mappings

**Use this if:** Your institution exports standard Sierra format with PCODE-based classification

**Critical:** PCODE2 and PCODE3 values must match database configuration

**Reference:** See `resources/patron_batchloading.txt` for complete Sierra format documentation

---

## Format Type Summary

### Type 1: Sierra Text File Image (Format 3)
**Parsers:** Truman, Covenant, KCKCC, Missouri Western

**Characteristics:**
- Multi-line records (one line per field)
- 24-character fixed-length zero-line
- Tagged variable-length fields (n, a, t, h, p, d, u, b, z, x)
- CR+LF line endings
- Official Innovative Interfaces format

**Documentation:** `resources/patron_batchloading.txt`

---

### Type 2: Excel/CSV with Sierra Zero-Line
**Parsers:** State Tech, Stephens

**Characteristics:**
- Single row per patron (spreadsheet format)
- One column contains Sierra zero-line encoded metadata
- Other columns contain standard patron data
- Combines Sierra metadata encoding with spreadsheet convenience

---

### Type 3: Excel/CSV Direct Mapping
**Parsers:** Goldfarb, Wichita

**Characteristics:**
- Single row per patron
- Each field has its own column
- No encoded metadata
- Simplest format for manual file preparation

---

### Type 4: CSV Multi-Column/Tagged
**Parsers:** MBTS, TRC

**Characteristics:**
- Hybrid approaches combining fixed-length and column-based data
- MBTS: Line1-Line10 columns with tagged data
- TRC: Special `text` field with packed PCODE data
- Specialized institutional formats

---

## Getting Started

### For New Institutions

1. **Identify your format:**
   - Do you export from Sierra ILS? → Start with Sierra Text File Image parsers
   - Do you export from custom system? → Consider direct mapping formats

2. **Review relevant specification:**
   - Find your institution in the index above
   - Open the corresponding PDF specification
   - Review column headers and format requirements

3. **Coordinate with MOBIUS:**
   - Contact MOBIUS before first submission
   - Verify PCODE mappings if applicable
   - Confirm unique ID suffix format
   - Schedule test load

4. **Prepare test file:**
   - Create small file with 5-10 patron records
   - Follow specification exactly
   - Submit for test processing

5. **Production loads:**
   - Once test succeeds, proceed with full patron loads
   - Can be scheduled weekly or as needed

---

## File Naming Conventions

### Recommended Format
```
YYYY-MM-DD-{Institution}-{PatronType}.{extension}

Examples:
2026-01-08-StateTech-Students.xlsx
2026-01-08-Truman-Faculty.txt
2026-01-08-Wichita-AllPatrons.csv
```

### Components
- **YYYY-MM-DD:** Date of export or submission
- **Institution:** Your institution name
- **PatronType:** Optional descriptor (Students, Faculty, All, etc.)
- **Extension:** `.xlsx`, `.csv`, `.txt` (format-dependent)

---

## Common Questions

### "Which specification should I use?"
Find your institution name in the "Detailed Parser Index" section above.

### "Can I change the file format?"
No - each parser expects a specific format. If you need a different format, contact MOBIUS to discuss options.

### "What if my column names don't match?"
Column names must match exactly (case-sensitive). You'll need to rename columns in your export to match the specification.

### "Can I omit optional fields?"
Yes - optional fields can be empty or omitted entirely. Required fields must be present.

### "How do I know if my PCODE values are correct?"
Contact MOBIUS before first submission to verify PCODE mappings (applies to Missouri Western and Covenant).

---

## Support and Resources

### MOBIUS Consortium Office
**Email:** support@mobiusconsortium.org
**Website:** https://mobiusconsortium.org

### Documentation
- **Sierra Format:** `resources/patron_batchloading.txt` (Official batchloading guide)
- **Parser Code:** `lib/Parsers/` directory (reference implementation)

### Before First Submission
1. Contact MOBIUS to introduce yourself
2. Confirm your institution's parser configuration
3. Verify any special mappings (PCODE, department, etc.)
4. Request test load with small sample file
5. Schedule regular load frequency

---

## Specification Documents

All specifications are available in both markdown and PDF formats:

### Markdown Source Files
- `markdown/StateTech-FileSpec.md`
- `markdown/Stephens-FileSpec.md`
- `markdown/Goldfarb-FileSpec.md`
- `markdown/MBTS-FileSpec.md`
- `markdown/Wichita-FileSpec.md`
- `markdown/TRC-FileSpec.md`
- `markdown/Truman-FileSpec.md`
- `markdown/Covenant-FileSpec.md`
- `markdown/KCKCC-FileSpec.md`
- `markdown/MissouriWestern-FileSpec.md`

### PDF Documents
- `StateTech-FileSpec.pdf`
- `Stephens-FileSpec.pdf`
- `Goldfarb-FileSpec.pdf`
- `MBTS-FileSpec.pdf`
- `Wichita-FileSpec.pdf`
- `TRC-FileSpec.pdf`
- `Truman-FileSpec.pdf`
- `Covenant-FileSpec.pdf`
- `KCKCC-FileSpec.pdf`
- `MissouriWestern-FileSpec.pdf`

---

**Document Version:** 1.0
**Generated:** January 2026
**Maintained By:** MOBIUS Consortium Office

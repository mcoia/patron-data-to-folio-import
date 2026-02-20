-- Migration 002: Add pcode mapping tables and note column
-- Schema definitions only - data inserts should be done separately per institution

-- Note: These tables may already exist from 000-initial-schema.sql for new installs
-- Using IF NOT EXISTS for idempotency

CREATE TABLE IF NOT EXISTS patron_import.pcode1_mapping (
    id SERIAL PRIMARY KEY,
    institution_id INT REFERENCES patron_import.institution(id),
    pcode1 TEXT,
    pcode1_value TEXT
);

CREATE TABLE IF NOT EXISTS patron_import.pcode2_mapping (
    id SERIAL PRIMARY KEY,
    institution_id INT REFERENCES patron_import.institution(id),
    pcode2 TEXT,
    pcode2_value TEXT
);

CREATE TABLE IF NOT EXISTS patron_import.pcode3_mapping (
    id SERIAL PRIMARY KEY,
    institution_id INT REFERENCES patron_import.institution(id),
    pcode3 TEXT,
    pcode3_value TEXT
);

-- Add note column to patron table (may already exist)
ALTER TABLE patron_import.patron ADD COLUMN IF NOT EXISTS note TEXT;

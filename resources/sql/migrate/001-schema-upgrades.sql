-- Migration 001: Schema Upgrades
-- ALTERs and constraint changes for existing installations
-- Note: Some of these may already be in 000-initial-schema.sql for new installs

ALTER TABLE patron_import.patron ADD COLUMN IF NOT EXISTS address1_one_liner TEXT;
ALTER TABLE patron_import.patron ADD COLUMN IF NOT EXISTS address2_one_liner TEXT;

ALTER TABLE patron_import.address ALTER COLUMN addresstypeid SET DEFAULT 'Address 1';

ALTER TABLE patron_import.institution ADD COLUMN IF NOT EXISTS abbreviation TEXT;

-- ESID is unique per institution
-- Note: This constraint may fail if duplicates exist; clean data first
ALTER TABLE patron_import.patron
    ADD CONSTRAINT IF NOT EXISTS unique_esid_per_institution UNIQUE (institution_id, externalsystemid);

-- username is unique across all institutions
ALTER TABLE patron_import.patron
    ADD CONSTRAINT IF NOT EXISTS unique_username UNIQUE (username);

-- remove these constraints (file_id FK was causing issues)
ALTER TABLE patron_import.stage_patron DROP CONSTRAINT IF EXISTS stage_patron_file_id_fkey;
ALTER TABLE patron_import.patron DROP CONSTRAINT IF EXISTS patron_file_id_fkey;

ALTER TABLE patron_import.patron ADD COLUMN IF NOT EXISTS custom_fields TEXT;
ALTER TABLE patron_import.stage_patron ADD COLUMN IF NOT EXISTS custom_fields TEXT;

-- departments column
ALTER TABLE patron_import.stage_patron ADD COLUMN IF NOT EXISTS departments TEXT[];
ALTER TABLE patron_import.patron ADD COLUMN IF NOT EXISTS departments TEXT[];

-- Convert department from text to text[] if needed
-- Note: This may fail if column already has data; handle manually if needed
-- ALTER TABLE patron_import.stage_patron ALTER COLUMN department TYPE text[];

-- Update parser module names
UPDATE patron_import.institution SET module = 'SierraParser' WHERE module = 'GenericParser';

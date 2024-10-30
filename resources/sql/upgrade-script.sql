ALTER TABLE patron_import.patron ADD COLUMN address1_one_liner TEXT;
ALTER TABLE patron_import.patron ADD COLUMN address2_one_liner TEXT;

ALTER TABLE patron_import.address ALTER COLUMN addresstypeid SET DEFAULT 'Address 1';

ALTER TABLE patron_import.institution ADD COLUMN IF NOT EXISTS abbreviation TEXT;

-- ESID is unique per institution
ALTER TABLE patron_import.patron
    ADD CONSTRAINT unique_esid_per_institution UNIQUE (institution_id, externalsystemid);

-- username is unique across all institutions
ALTER TABLE patron_import.patron
    ADD CONSTRAINT unique_username UNIQUE (username);



-- remove these constraints
ALTER TABLE patron_import.stage_patron DROP CONSTRAINT stage_patron_file_id_fkey;
ALTER TABLE patron_import.patron DROP CONSTRAINT patron_file_id_fkey;

ALTER TABLE patron_import.patron ADD COLUMN IF NOT EXISTS custom_fields TEXT;
ALTER TABLE patron_import.stage_patron ADD COLUMN IF NOT EXISTS custom_fields TEXT;

-- departments            text[],
ALTER TABLE patron_import.stage_patron ADD COLUMN IF NOT EXISTS departments TEXT[];
ALTER TABLE patron_import.patron ADD COLUMN IF NOT EXISTS departments TEXT[];



-- We need to alter the existing column and convert it into an array.
-- UPDATE patron_import.stage_patron SET department = NULL;
ALTER TABLE patron_import.stage_patron ALTER COLUMN department TYPE text[];

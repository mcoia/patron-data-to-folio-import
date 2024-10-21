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
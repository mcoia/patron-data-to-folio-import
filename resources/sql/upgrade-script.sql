ALTER TABLE patron_import.patron ADD COLUMN address1_one_liner TEXT;
ALTER TABLE patron_import.patron ADD COLUMN address2_one_liner TEXT;

ALTER TABLE patron_import.address ALTER COLUMN addresstypeid SET DEFAULT 'Address 1';


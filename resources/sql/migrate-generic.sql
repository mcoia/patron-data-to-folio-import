-- dedupe stage_patron
UPDATE patron_import.stage_patron sp
SET load = true
FROM (SELECT MIN(id) as id
      FROM patron_import.stage_patron
      where not load
      GROUP BY unique_id
      HAVING COUNT(*) > 1) b
WHERE sp.id = b.id
  AND btrim(sp.unique_id) != ''
  AND btrim(sp.esid) != ''
  AND sp.unique_id is not null
  AND sp.esid is not null
  AND not sp.load;

UPDATE patron_import.stage_patron sp
SET load = true
FROM (SELECT MIN(id) as id
      FROM patron_import.stage_patron
      where not load
      GROUP BY unique_id
      HAVING COUNT(*) = 1) b
WHERE sp.id = b.id
  AND btrim(sp.unique_id) != ''
  AND btrim(sp.esid) != ''
  AND sp.unique_id is not null
  AND sp.esid is not null
  AND not sp.load;

INSERT INTO patron_import.patron (institution_id,
                                  file_id,
                                  job_id,
                                  raw_data,
                                  fingerprint,
                                  username,
                                  externalsystemid,
                                  barcode,
                                  email,
                                  patrongroup,
                                  lastname,
                                  middlename,
                                  firstname,
                                  phone,
                                  mobilephone,
                                  preferredcontacttypeid,
                                  expirationdate)
    (SELECT sp.institution_id,
            sp.file_id,
            sp.job_id,
            sp.raw_data,
            sp.fingerprint,
            sp.unique_id,
            sp.esid,
            sp.barcode,
            sp.email_address,
            pt.foliogroup,
            btrim(regexp_replace(sp.name, ',.*', ''))                              as "lastname",
            btrim(regexp_replace(regexp_replace(sp.name, '.*, ', ''), '.*\s', '')) as "middlename",
            btrim(regexp_replace(regexp_replace(sp.name, '.*, ', ''), '\s.*', '')) as "firstname",
            btrim(regexp_replace(sp.telephone, '[^0-9|^\-]', '')),  -- remove all non-numeric characters except for - from phone number, was getting a lot of errors
            btrim(regexp_replace(sp.telephone2, '[^0-9|^\-]', '')), -- change to [0-9-]+ <== that's easier to read.
            'email',
            (CASE
                 WHEN sp.patron_expiration_date ~ '\d{2}[\-\/\.]\d{2}[\-\/\.]\d{2,4}' then sp.patron_expiration_date::DATE::TEXT
                 else NULL END)
     FROM patron_import.stage_patron sp
              JOIN patron_import.institution i ON (sp.institution_id = i.id)
              LEFT JOIN patron_import.ptype_mapping pt on (pt.ptype = sp.patron_type AND pt.institution_id = i.id)
              LEFT JOIN patron_import.patron p2 ON (sp.unique_id = p2.username)
     WHERE p2.id IS NULL
       AND sp.unique_id IS NOT NULL
       AND sp.unique_id != ''
       AND sp.esid IS NOT NULL
       AND sp.esid != ''
       AND sp.load);


UPDATE patron_import.patron p
SET file_id                = sp.file_id,
    job_id                 = sp.job_id,
    fingerprint            = sp.fingerprint,
    username               = sp.unique_id,
    externalsystemid       = sp.esid,
    barcode                = sp.barcode,
    patrongroup            = pt.foliogroup,
    lastname               = btrim(regexp_replace(sp.name, ',.*', '')),
    middlename             = btrim(regexp_replace(regexp_replace(sp.name, '.*, ', ''), '.*\s', '')),
    firstname              = btrim(regexp_replace(regexp_replace(sp.name, '.*, ', ''), '\s.*', '')),
    phone                  = btrim(regexp_replace(sp.telephone, '[0-9-]+', '')),  -- remove all non-numeric characters except for - from phone number, was getting a lot of errors
    mobilephone            = btrim(regexp_replace(sp.telephone2, '[0-9-]+', '')), -- change [^0-9|^\-] to [0-9-]+ <== that's easier to read.
    preferredcontacttypeid = 'email',
    ready                  = true,
    update_date            = now(),
    expirationdate         = (CASE
                                  WHEN sp.patron_expiration_date ~ '\d{2}[\-\/\.]\d{2}[\-\/\.]\d{2,4}'
                                      THEN sp.patron_expiration_date::DATE::TEXT
                                  ELSE NULL END)
FROM patron_import.stage_patron sp
         JOIN patron_import.institution i on (sp.institution_id = i.id)
         LEFT JOIN patron_import.ptype_mapping pt on (pt.ptype = sp.patron_type and pt.institution_id = i.id)
WHERE sp.fingerprint != p.fingerprint
  AND sp.unique_id = p.username
  AND sp.load;

-- why is this here?!? We shouldn't be inserting anything without an externalsystemid
-- convert our '' to NULLs
-- external system id
UPDATE patron_import.patron
SET externalsystemid=NULL
WHERE externalsystemid = '';

-- username
UPDATE patron_import.patron
SET username=NULL
WHERE username = '';

-- we don't load patrons without an external system id or username.
UPDATE patron_import.patron
SET ready = false
WHERE externalsystemid is NULL
   or username is NULL;

TRUNCATE patron_import.stage_patron;
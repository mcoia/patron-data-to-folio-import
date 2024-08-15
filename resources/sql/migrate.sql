------------------------
-- Stage Patron Clean Up
------------------------
UPDATE patron_import.stage_patron
SET unique_id = BTRIM(LOWER(unique_id));

-- Remove rows that have blank keys
DELETE
FROM patron_import.stage_patron sp
WHERE BTRIM(sp.esid) = ''
   OR sp.esid IS NULL;

DELETE
FROM patron_import.stage_patron sp
WHERE BTRIM(sp.unique_id) = ''
   OR sp.unique_id IS NULL;

-- Make higher priority patron types win over lower on duplicate patron rows
DELETE
FROM patron_import.stage_patron
WHERE id IN
      (SELECT sp2.id
       FROM patron_import.stage_patron sp
                JOIN patron_import.stage_patron sp2
                     ON (sp.unique_id = sp2.unique_id AND sp.id != sp2.id AND sp.patron_type != sp2.patron_type AND
                         sp.institution_id = sp2.institution_id)
                JOIN patron_import.ptype_mapping pt
                     ON (pt.institution_id = sp.institution_id AND pt.ptype = sp.patron_type)
                JOIN patron_import.ptype_mapping pt2
                     ON (pt2.institution_id = sp2.institution_id AND pt2.ptype = sp2.patron_type)
       WHERE pt.priority < pt2.priority);

-- Remove patrons that have a lower load priority than what we already have in the patron table. (ptype_mapping.priority)
DELETE
FROM patron_import.stage_patron
WHERE id IN (SELECT sp.id
             FROM patron_import.stage_patron sp
                      JOIN patron_import.patron p
                           ON p.externalsystemid = sp.esid AND BTRIM(LOWER(p.username)) = BTRIM(LOWER(sp.unique_id))
                      JOIN patron_import.ptype_mapping pt
                           ON pt.institution_id = sp.institution_id AND pt.ptype = sp.patron_type
                      JOIN patron_import.ptype_mapping pt2
                           ON pt2.institution_id = sp.institution_id AND p.patrongroup = pt2.foliogroup
             WHERE pt.priority > pt2.priority);

-- dedupe stage_patron
UPDATE patron_import.stage_patron sp
SET load = TRUE
FROM (SELECT MIN(id) as id
      FROM patron_import.stage_patron
      WHERE NOT load
      GROUP BY unique_id
      HAVING COUNT(*) = 1) b
WHERE sp.id = b.id
  AND BTRIM(sp.unique_id) != ''
  AND BTRIM(sp.esid) != ''
  AND sp.unique_id IS NOT NULL
  AND sp.esid IS NOT NULL
  AND NOT sp.load;

-- wait... isn't this just another way of writing the update statement above?? lol logically speaking.
-- We have got to remove these duplicates
DELETE
FROM patron_import.stage_patron p3
WHERE p3.id IN (SELECT p.id
                FROM patron_import.stage_patron p
                WHERE p.unique_id IN (SELECT p1.unique_id
                                      FROM patron_import.stage_patron p1
                                      GROUP BY p1.unique_id
                                      HAVING COUNT(*) > 1)
                  AND p.id NOT IN (SELECT MAX(p2.id)
                                   FROM patron_import.stage_patron p2
                                   GROUP BY p2.unique_id
                                   HAVING COUNT(*) > 1)
                ORDER BY p.unique_id);

-- delete all patrons who's fingerprint matches what's in the patron table.
DELETE
FROM patron_import.stage_patron
WHERE id IN (SELECT sp.id
             FROM patron_import.stage_patron sp
                      JOIN patron_import.patron p ON p.fingerprint = sp.fingerprint);

-- we don't delete the patron, we just clear the date when they put in some illegal format
UPDATE patron_import.stage_patron sp
SET patron_expiration_date = NULL
WHERE SUBSTRING(sp.patron_expiration_date FROM '^(\d+)')::INT > 12;

-- folio is subtracting a day from the expiration date. 12/10/2024 shows in folio as 12/09/2024 and it's confusing the staff
UPDATE patron_import.stage_patron
SET patron_expiration_date = (
    CASE
        WHEN patron_expiration_date IS NULL OR patron_expiration_date = '' THEN '1970-01-01'
        ELSE (patron_expiration_date::DATE + INTERVAL '1 day')::DATE
        END
    );

------------------------
-- Stage ==> Patron
------------------------

INSERT INTO patron_import.patron (institution_id,
                                  file_id,
                                  job_id,
                                  raw_data,
                                  address1_one_liner,
                                  address2_one_liner,
                                  fingerprint,
                                  username,
                                  externalsystemid,
                                  barcode,
                                  email,
                                  patrongroup,
                                  lastname,
                                  middlename,
                                  firstname,
                                  preferredfirstname,
                                  phone,
                                  mobilephone,
                                  preferredcontacttypeid,
                                  expirationdate)
    (SELECT sp.institution_id,
            sp.file_id,
            sp.job_id,
            sp.raw_data,
            sp.address,
            sp.address2,
            sp.fingerprint,
            BTRIM(sp.unique_id),
            BTRIM(sp.esid),
            BTRIM(sp.barcode),
            BTRIM(sp.email_address),
            pt.foliogroup,
            BTRIM(REGEXP_REPLACE(sp.name, ',.*', ''))                              AS "lastname",
            BTRIM(REGEXP_REPLACE(REGEXP_REPLACE(sp.name, '.*, ', ''), '.*\s', '')) AS "middlename",
            BTRIM(REGEXP_REPLACE(REGEXP_REPLACE(sp.name, '.*, ', ''), '\s.*', '')) AS "firstname",
            CASE
                WHEN sp.preferred_name LIKE '%, %' THEN
                    SUBSTRING(sp.preferred_name FROM ', (.*) ')
                ELSE NULL END,
            BTRIM(REGEXP_REPLACE(sp.telephone, '[^0-9|^\-]', '')),
            BTRIM(REGEXP_REPLACE(sp.telephone2, '[^0-9|^\-]', '')),
            'email',
            (CASE
                 WHEN sp.patron_expiration_date ~ '\d{1,2}[\-\/\.]\d{2}[\-\/\.]\d{2,4}' THEN sp.patron_expiration_date::DATE::TEXT
                 ELSE NULL END)
     FROM patron_import.stage_patron sp
              JOIN patron_import.institution i ON (sp.institution_id = i.id)
              LEFT JOIN patron_import.ptype_mapping pt ON (pt.ptype = sp.patron_type AND pt.institution_id = i.id)
              LEFT JOIN patron_import.patron p2 ON (BTRIM(LOWER(sp.unique_id)) = BTRIM(LOWER(p2.username)))
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
    username               = BTRIM(sp.unique_id),
    externalsystemid       = BTRIM(sp.esid),
    barcode                = BTRIM(sp.barcode),
    patrongroup            = pt.foliogroup,
    email                  = BTRIM(sp.email_address),
    lastname               = BTRIM(REGEXP_REPLACE(sp.name, ',.*', '')),
    middlename             = BTRIM(REGEXP_REPLACE(REGEXP_REPLACE(sp.name, '.*, ', ''), '.*\s', '')),
    firstname              = BTRIM(REGEXP_REPLACE(REGEXP_REPLACE(sp.name, '.*, ', ''), '\s.*', '')),
    preferredfirstname     = CASE
                                 WHEN sp.preferred_name LIKE '%, %' THEN
                                     SUBSTRING(sp.preferred_name FROM ', (.*) ')
                                 ELSE NULL END,
    phone                  = BTRIM(sp.telephone),
    mobilephone            = BTRIM(sp.telephone2),
    preferredcontacttypeid = 'email',
    ready                  = TRUE,
    update_date            = NOW(),
    raw_data               = sp.raw_data,
    address1_one_liner     = sp.address,
    address2_one_liner     = sp.address2,
    expirationdate         = (CASE
                                  WHEN sp.patron_expiration_date ~ '\d{1,2}[\-\/\.]\d{2}[\-\/\.]\d{2,4}'
                                      THEN sp.patron_expiration_date::DATE::TEXT
                                  ELSE NULL END)
FROM patron_import.stage_patron sp
         JOIN patron_import.institution i ON (sp.institution_id = i.id)
         LEFT JOIN patron_import.ptype_mapping pt ON (pt.ptype = sp.patron_type AND pt.institution_id = i.id)
WHERE BTRIM(LOWER(sp.unique_id)) = BTRIM(LOWER(p.username))
  AND sp.fingerprint != p.fingerprint
  AND sp.esid = p.externalsystemid
  AND sp.load;

------------------------
-- Patron Clean Up
------------------------

-- fix these middle names
UPDATE patron_import.patron p
SET middlename = ''
WHERE p.firstname = p.middlename;

UPDATE patron_import.patron
SET expirationdate = NULL
WHERE expirationdate = '';

-- Clean up some of these addresses only having a $ dollar sign or being ''. We want NULL for these.
update patron_import.address
set addressline1 = NULL
where BTRIM(addressline1) = '';

update patron_import.address
set addressline2 = NULL
where BTRIM(addressline2) = '';

update patron_import.address
set addressline1 = NULL
where BTRIM(addressline1) = '$';

update patron_import.address
set addressline2 = NULL
where BTRIM(addressline2) = '$';

------------------------
-- Patron Validation
------------------------

-- set ready false for '' on last name. folio requires a last name
UPDATE patron_import.patron p
SET ready    = FALSE,
    lastname = NULL
WHERE p.lastname = ''
   OR p.lastname IS NULL;

-- patron table maintenance
-- external system id
UPDATE patron_import.patron
SET ready            = FALSE,
    externalsystemid = NULL
WHERE externalsystemid = '';

-- username
UPDATE patron_import.patron
SET ready    = FALSE,
    username = NULL
WHERE username = '';

-- we don't load patrons without a patron group associated.
UPDATE patron_import.patron
SET ready = FALSE
WHERE patrongroup IS NULL;


-- I like having this here. after we run this SQL file, we check the size of stage_patron
-- if we still have patrons in this table we halt execution. Something went wrong.
TRUNCATE patron_import.stage_patron;

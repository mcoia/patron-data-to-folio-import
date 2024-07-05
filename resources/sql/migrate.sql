-- Remove rows that have blank keys
DELETE
FROM patron_import.stage_patron sp
WHERE btrim(sp.esid) = '' or sp.esid is NULL;
DELETE
FROM patron_import.stage_patron sp
WHERE btrim(sp.unique_id) = '' or sp.unique_id is NULL;

-- Make higher priority patron types win over lower on duplicate patron rows
DELETE
FROM patron_import.stage_patron
WHERE id IN
      (SELECT sp2.id
       FROM patron_import.stage_patron sp
                JOIN patron_import.stage_patron sp2
                     ON (sp.unique_id = sp2.unique_id and sp.id != sp2.id and sp.patron_type != sp2.patron_type and
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
                      JOIN patron_import.patron p ON p.externalsystemid = sp.esid AND p.username = sp.unique_id
                      JOIN patron_import.ptype_mapping pt
                           ON pt.institution_id = sp.institution_id AND pt.ptype = sp.patron_type
                      JOIN patron_import.ptype_mapping pt2
                           ON pt2.institution_id = sp.institution_id AND p.patrongroup = pt2.foliogroup
             WHERE pt.priority > pt2.priority);

-- dedupe stage_patron
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

-- we don't delete the patron, we just clear the date when they put in some illegal format
UPDATE patron_import.stage_patron sp
SET patron_expiration_date=NULL
WHERE substring(sp.patron_expiration_date from '^(\d+)')::INT > 12;

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
            btrim(sp.unique_id),
            btrim(sp.esid),
            btrim(sp.barcode),
            btrim(sp.email_address),
            pt.foliogroup,
            btrim(regexp_replace(sp.name, ',.*', ''))                              as "lastname",
            btrim(regexp_replace(regexp_replace(sp.name, '.*, ', ''), '.*\s', '')) as "middlename",
            btrim(regexp_replace(regexp_replace(sp.name, '.*, ', ''), '\s.*', '')) as "firstname",
            btrim(regexp_replace(sp.telephone, '[^0-9|^\-]', '')),
            btrim(regexp_replace(sp.telephone2, '[^0-9|^\-]', '')),
            'email',
            (CASE
                 WHEN sp.patron_expiration_date ~ '\d{1,2}[\-\/\.]\d{2}[\-\/\.]\d{2,4}' then sp.patron_expiration_date::DATE::TEXT
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
    username               = btrim(sp.unique_id),
    externalsystemid       = btrim(sp.esid),
    barcode                = btrim(sp.barcode),
    patrongroup            = pt.foliogroup,
    lastname               = btrim(regexp_replace(sp.name, ',.*', '')),
    middlename             = btrim(regexp_replace(regexp_replace(sp.name, '.*, ', ''), '.*\s', '')),
    firstname              = btrim(regexp_replace(regexp_replace(sp.name, '.*, ', ''), '\s.*', '')),
    phone                  = btrim(regexp_replace(sp.telephone, '[0-9-]+', '')),
    mobilephone            = btrim(regexp_replace(sp.telephone2, '[0-9-]+', '')),
    preferredcontacttypeid = 'email',
    ready                  = true,
    update_date            = now(),
    raw_data               = sp.raw_data,
    expirationdate         = (CASE
                                  WHEN sp.patron_expiration_date ~ '\d{1,2}[\-\/\.]\d{2}[\-\/\.]\d{2,4}'
                                      THEN sp.patron_expiration_date::DATE::TEXT
                                  ELSE NULL END)
FROM patron_import.stage_patron sp
         JOIN patron_import.institution i on (sp.institution_id = i.id)
         LEFT JOIN patron_import.ptype_mapping pt on (pt.ptype = sp.patron_type and pt.institution_id = i.id)
WHERE sp.unique_id = p.username
  AND sp.fingerprint != p.fingerprint
  AND sp.esid = p.externalsystemid
  AND sp.load;

-- fix these middle names
update patron_import.patron p
set middlename=''
where p.firstname = p.middlename;

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

-- clean up ALL patrons.
-- we don't load patrons without an external system id, username and they must have a patron group associated.
update patron_import.patron
set ready= false
where patrongroup is null
   or externalsystemid is null
   or username is null;

update patron_import.patron
    set expirationdate=NULL
    where expirationdate='';

-- I like having this here. after we run this sql file, we check the size of stage_patron
-- if we still have patrons in this table we halt execution. Something went wrong. We have bad data
-- and we don't want 'data pollution' in the patron db. We have to fix it.
TRUNCATE patron_import.stage_patron;
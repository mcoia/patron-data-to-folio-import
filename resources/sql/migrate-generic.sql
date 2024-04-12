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

insert into patron_import.patron (institution_id,
                                  file_id,
                                  job_id,
                                  fingerprint,
                                  username,
                                  externalsystemid,
                                  barcode,
                                  patrongroup,
                                  lastname,
                                  middlename,
                                  firstname,
                                  phone,
                                  mobilephone,
                                  preferredcontacttypeid,
                                  expirationdate)
    (select sp.institution_id,
            sp.file_id,
            sp.job_id,
            sp.fingerprint,
            sp.unique_id,
            sp.esid,
            sp.barcode,
            pt.foliogroup,
            btrim(regexp_replace(sp.name, ',.*', ''))                              as "lastname",
            btrim(regexp_replace(regexp_replace(sp.name, '.*, ', ''), '.*\s', '')) as "middlename",
            btrim(regexp_replace(regexp_replace(sp.name, '.*, ', ''), '\s.*', '')) as "firstname",
            sp.telephone,
            sp.telephone2,
            'email',
            (case
                 when sp.patron_expiration_date ~ '\d{2}[\-\/\.]\d{2}[\-\/\.]\d{2,4}' then sp.patron_expiration_date::DATE::TEXT
                 else NULL END)
     from patron_import.stage_patron sp
              join patron_import.institution i on (sp.institution_id = i.id)
              left join patron_import.ptype_mapping pt on (pt.ptype = sp.patron_type and pt.institution_id = i.id)
              left join patron_import.patron p2 on (sp.unique_id = p2.username)
     where p2.id is null
       AND sp.load);


update patron_import.patron p
set file_id                = sp.file_id,
    job_id                 = sp.job_id,
    fingerprint            = sp.fingerprint,
    username               = sp.unique_id,
    externalsystemid       = sp.esid,
    barcode                = sp.barcode,
    patrongroup            = pt.foliogroup,
    lastname               = btrim(regexp_replace(sp.name, ',.*', '')),
    middlename             = btrim(regexp_replace(regexp_replace(sp.name, '.*, ', ''), '.*\s', '')),
    firstname              = btrim(regexp_replace(regexp_replace(sp.name, '.*, ', ''), '\s.*', '')),
    phone                  = sp.telephone,
    mobilephone            = sp.telephone2,
    preferredcontacttypeid = 'email',
    expirationdate         = (case
                                  when sp.patron_expiration_date ~ '\d{2}[\-\/\.]\d{2}[\-\/\.]\d{2,4}'
                                      then sp.patron_expiration_date::DATE::TEXT
                                  else NULL END)
FROM patron_import.stage_patron sp
         join patron_import.institution i on (sp.institution_id = i.id)
         left join patron_import.ptype_mapping pt on (pt.ptype = sp.patron_type and pt.institution_id = i.id)
where sp.fingerprint != p.fingerprint
  AND sp.unique_id = p.username
  AND sp.load;

-- convert our '' to NULLs
-- external system id
update patron_import.patron
set externalsystemid=NULL
where externalsystemid = '';

-- username
update patron_import.patron
set username=NULL
where username = '';

-- we don't load patrons without an external system id or username.
update patron_import.patron
set ready = false
where externalsystemid is NULL
   or username is NULL;



truncate patron_import.stage_patron;
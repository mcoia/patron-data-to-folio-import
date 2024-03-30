-- dedupe stage_patron
UPDATE patron_import.stage_patron sp
SET load = true
FROM (SELECT MIN(id) as id
      FROM patron_import.stage_patron
      where not load
      GROUP BY unique_id
      HAVING COUNT(*) > 1) b
WHERE sp.id = b.id
  AND not sp.load;


UPDATE patron_import.stage_patron sp
SET load = true
FROM (SELECT MIN(id) as id
      FROM patron_import.stage_patron
      where not load
      GROUP BY unique_id
      HAVING COUNT(*) = 1) b
WHERE sp.id = b.id
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
                                  firstname,
                                  middlename,
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
            sp.patron_expiration_date
     from patron_import.stage_patron sp
              join patron_import.institution i on (sp.institution_id = i.id)
              left join patron_import.ptype_mapping pt on (pt.ptype = sp.patron_type and pt.institution_id = i.id)
              left join patron_import.patron p2 on (sp.unique_id = p2.username)
     where p2.id is null
       AND sp.load);


update patron_import.patron fp
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
    preferredcontacttypeid = 'email'
FROM patron_import.stage_patron sp
         join patron_import.institution i
              on (sp.institution_id = i.id)
         left join patron_import.ptype_mapping pt on (pt.ptype = sp.patron_type and pt.institution_id = i.id)
where sp.fingerprint != fp.fingerprint
  AND sp.unique_id = fp.username
  AND sp.load;


-- look for duplicate unique_id
select *
from patron_import.stage_patron sp
         left join patron_import.patron p on (sp.unique_id = p.username)
where sp.institution_id != p.institution_id;


-- truncate patron_import.stage_patron;
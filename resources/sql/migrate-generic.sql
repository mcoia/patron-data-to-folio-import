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
                                  preferredcontacttypeid)
    (select p.institution_id,
            p.file_id,
            p.job_id,
            p.fingerprint,
            p.unique_id,
            p.esid,
            p.barcode,
            pt.foliogroup,
            btrim(regexp_replace(p.name, ',.*', ''))                              as "lastname",
            btrim(regexp_replace(regexp_replace(p.name, '.*, ', ''), '.*\s', '')) as "middlename",
            btrim(regexp_replace(regexp_replace(p.name, '.*, ', ''), '\s.*', '')) as "firstname",
            p.telephone,
            p.telephone2,
            'email'
     from patron_import.stage_patron p
              join patron_import.institution i on (p.institution_id = i.id)
              left join patron_import.ptype_mapping pt on (pt.ptype = p.patron_type and pt.institution_id = i.id)
              left join patron_import.patron p2 on (p.unique_id = p2.username)
     where p2.id is null
       AND p.load);

truncate patron_import.stage_patron;
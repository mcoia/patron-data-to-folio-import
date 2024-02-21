select i.institution, e.c3
from patron_import.institution_map i
         join patron_import.esid_mapping_sheet e on (i.institution = e.c1);


select i.institution, i.esid, e.c3
from patron_import.institution_map i
         join patron_import.esid_mapping_sheet e on (i.institution = e.c1)
where e.c3 ~ 'email'
order by institution asc;


-- show me the current esid mappings
select i.institution, i.esid from patron_import.institution_map i where i.esid != '';

-- show me the empty esid fields
select i.institution, i.esid from patron_import.institution_map i where i.esid = '';

-- clear out the fields
update patron_import.institution_map i
set esid='' where esid ='email' ;


-- set esid -> email
update patron_import.institution_map i
set esid='email'
where i.institution in (select i.institution from patron_import.institution_map i
                                                      join patron_import.esid_mapping_sheet e on (i.institution = e.c1)
                        where e.c3 ~ '^email');

-- set esid -> barcode
update patron_import.institution_map i
set esid='barcode'
where i.institution in (select i.institution from patron_import.institution_map i
                                                      join patron_import.esid_mapping_sheet e on (i.institution = e.c1)
                        where e.c3 ~ '^barcode');


update patron_import.institution_map i
set esid='barcode'
where i.institution in (select i.institution from patron_import.institution_map i
                                                      join patron_import.esid_mapping_sheet e on (i.institution = e.c1)
                        where e.c3 ~ '^barcode');

-- get patron groups for institution
select * from patron_import.ptype_mapping pt
         join patron_import.institution i on pt.institution_id=i.id
where i.name~'Eden';


-- disable all institutions
update patron_import.institution set enabled=false where id>0;

-- enable institution
update patron_import.institution set enabled=true where id=:institution_id;


-- distill all the institutions that have patrons the don't map to a ptype
-- select distinct p2.institution_id, i.name, f.name, t.path
-- select p2.institution_id, i.name, t.path, f.name
select t.path
from patron_import.patron p2
         join patron_import.institution i on (i.id = p2.institution_id)
         join patron_import.file f on (f.institution_id = i.id)
         join patron_import.file_tracker t on (t.institution_id = i.id)
where p2.patrongroup is NULL
group by 1;



select count(*)
from patron_import.ptype_mapping ptype;



select count(*)
from patron_import.patron p
where p.patrongroup is null;


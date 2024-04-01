-- How many NULL patron groups?
-- 736
select count(p.*)
from patron_import.patron p
where p.patrongroup is NULL;

-- which institutions are these?
select distinct i.id, i.name
from patron_import.patron p
         join patron_import.institution i on i.id = p.institution_id
where p.patrongroup is NULL;
-- +--+-----------------------------------+
-- |id|name                               |
-- +--+-----------------------------------+
-- |15|Central Methodist University       |
-- |37|Avila University                   |
-- |46|Missouri Western State University  |
-- |49|Northwest Missouri State University|
-- +--+-----------------------------------+

-- get null counts per institution
select count(*), i.name
from patron_import.patron p
         join patron_import.institution i on i.id = p.institution_id
where p.patrongroup is NULL
group by i.name;

-- show me all the patrons from a specific institution
select *
from patron_import.patron p
         join patron_import.institution i on i.id = p.institution_id
where p.patrongroup is NULL
  and i.id = 15;
-- 299

-- isolate the institutions for debugging.
update patron_import.institution
set enabled = false
where id not in (select distinct i.id
                 from patron_import.patron p
                          join patron_import.institution i on i.id = p.institution_id
                 where p.patrongroup is NULL);

--- #################### SCRATCH BELOW ####################
-- select count(*), i.name, ft.path
select count(*), ft.path
from patron_import.patron p
         join patron_import.institution i on i.id = p.institution_id
         join patron_import.file_tracker ft on ft.institution_id = i.id
where p.patrongroup is NULL
group by i.name, ft.path;

select distinct ft.path
from patron_import.patron p
         join patron_import.institution i on i.id=p.institution_id
         join patron_import.file_tracker ft on ft.institution_id=i.id
where p.patrongroup is NULL
  and p.institution_id=15;


select * from patron_import.ptype_mapping pt where pt.institution_id=15;


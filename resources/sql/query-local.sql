
-- Get all enabled institutions
select i.id from patron_import.institution i where i.enabled = true order by i.id;
select i.id, i.name from patron_import.institution i where i.enabled = true;

-- All enabled institutions:
-- 2,3,4,5,6,7,8,9,13,14,15,16,17,18,19,21,22,23,24,25,26,27,28,29,30,31,32,33,34,39,42,43,44,45,46,47,49,50,51,54,55,56,57,58,59,60,61,62,63,64


-- Disable all institutions
update patron_import.institution set enabled = false where id > 0;

-- Enable all institutions
update patron_import.institution set enabled = true where id in(2,3,4,5,6,7,8,9,13,14,15,16,17,18,19,21,22,23,24,25,26,27,28,29,30,31,32,33,34,39,42,43,44,45,46,47,49,50,51,54,55,56,57,58,59,60,61,62,63,64);

-- Enable a single institution
update patron_import.institution set enabled = true where id = 19;

-- Disable a single institution
update patron_import.institution set enabled = false where id = 2;

-- Get all patrons for an institution
select * from patron_import.patron p where p.institution_id = 2;



-- show staged_patrons
select * from patron_import.stage_patron sp;

-- show patrons
select * from patron_import.patron p;

select * from patron_import.patron p where p.institution_id = 22;

select count(*) from patron_import.patron p;
select * from patron_import.patron p;

-- local development
-- purge all patrons
begin;

truncate patron_import.stage_patron;
select * from patron_import.stage_patron sp;
select * from patron_import.patron p;
select count(*) from patron_import.patron p;

-- delete patrons from patron_import.patron
delete from patron_import.address where patron_id in(select id from patron_import.patron where institution_id = 22);
delete from patron_import.patron where institution_id = 22;

truncate patron_import.address cascade ;
truncate patron_import.patron cascade ;

rollback;
commit;




select * from patron_import.patron p where p.patrongroup = 'MVC Student';

update patron_import.institution set enabled = true where id > 1;
update patron_import.institution set enabled = false where id > 0;


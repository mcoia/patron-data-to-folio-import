-- Get all enabled institutions
select i.id
from patron_import.institution i
where i.enabled = true;
select i.id, i.name
from patron_import.institution i
where i.enabled = true;

-- All enabled institutions:
-- 2,3,4,5,6,7,8,9,13,14,15,16,17,18,19,21,22,23,24,25,26,27,28,29,30,31,32,33,34,39,42,43,44,45,46,47,49,50,51,54,55,56,57,58,59,60,61,62,63,64

-- Disable all institutions
update patron_import.institution set enabled = false where id > 0;

-- Enable all institutions
update patron_import.institution
set enabled = true where id in (2, 3, 4, 5, 6, 7, 8, 9, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 39, 42, 43, 44, 45, 46, 47, 49, 50, 51, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64);

-- Enable a single institution
update patron_import.institution set enabled = true where id = 64;

-- Disable a single institution
update patron_import.institution
set enabled = false
where id = 2;

-- Get all patrons for an institution
select *
from patron_import.patron p
where p.institution_id = 2;
select count(*)
from patron_import.patron p
where p.institution_id = 2;

-- total patrons
select count(*)
from patron_import.patron p;

-- show staged_patrons
select *
from patron_import.stage_patron sp;

-- show patrons
select *
from patron_import.patron p;

select *
from patron_import.patron p
where p.institution_id = 12;


-- local development
-- purge all patrons
begin;

truncate patron_import.stage_patron;
delete
from patron_import.address
where patron_id in (select id from patron_import.patron where institution_id = 64);
delete
from patron_import.patron
where institution_id = 64;

rollback;
commit;



-- explore
-- id: 64, name: "Wichita State University"
-- total patrons 63142

select * from patron_import.patron p where p.institution_id = 64;

select count(*) from patron_import.patron p where p.institution_id = 64;
select count(*) from patron_import.patron p where p.institution_id = 64 and p.patrongroup is null;

-- null patron groups. 51266
select * from patron_import.ptype_mapping pt where pt.institution_id = 64;


begin;
UPDATE patron_import.patron SET fingerprint = NULL WHERE institution_id = 64;
ROLLBACK;

COMMIT;






-- THIS NEEDS TO BE ADDED!!!!

-- Drop the old trigger
-- DROP TRIGGER address_trigger ON patron_import.patron;
--
-- -- Create it with column-specific firing
-- CREATE TRIGGER address_trigger
--     AFTER INSERT OR UPDATE OF address1_one_liner, address2_one_liner
--     ON patron_import.patron
--     FOR EACH ROW
-- EXECUTE FUNCTION patron_import.address_trigger_function();
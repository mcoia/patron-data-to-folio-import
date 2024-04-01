-- select
select count(p.*) from patron_import.patron p where p.patrongroup is NULL;





select distinct i.name from patron_import.patron p join patron_import.institution i on i.id=p.institution_id
                  where p.patrongroup is NULL;

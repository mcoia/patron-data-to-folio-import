create table patron_import_files (
    ID SERIAL primary key,
    cluster varchar,
    institution varchar,
    filename varchar
);

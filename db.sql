create table job
(
    ID         SERIAL primary key,
    start_time timestamp,
    stop_time  timestamp
);

create table patron_import_files
(
    ID          SERIAL primary key,
    job_id      int,
    cluster     varchar,
    institution varchar,
    pattern     varchar,
    filename    varchar
);

create table patron
(
    ID                     SERIAL primary key,
    job_id                 int,
    externalID             varchar,
    active                 bool,
    username               varchar,
    patronGroup            varchar,
    addressTypeId          int,
    cluster                varchar,
    institution            varchar,
    field_code             varchar,
    patron_type            int,
    pcode1                 varchar,
    pcode2                 varchar,
    pcode3                 int,
    home_library           varchar,
    patron_message_code    varchar,
    patron_block_code      varchar,
    patron_expiration_date varchar,
    name                   varchar,
    address                varchar,
    telephone              varchar,
    address2               varchar,
    telephone2             varchar,
    department             varchar,
    unique_id              varchar,
    barcode                varchar,
    email_address          varchar,
    note                   varchar,
    file                   varchar
);

insert into job(start_time,stop_time) values (CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);

select * from job
          where start_time = stop_time
          order by ID desc limit 1 ;
create table if not exists institution_map
(
    ID           SERIAL primary key,
    cluster      varchar,
    institution  varchar,
    folder_path  varchar,
    file         varchar,
    file_pattern varchar,
    module       varchar
);

create table if not exists job
(
    ID         SERIAL primary key,
    start_time timestamp,
    stop_time  timestamp
);

create table if not exists file_tracker
(
    ID             SERIAL primary key,
    job_id         int references job (ID),
    institution_id int references institution_map (ID),
    filename       varchar
);

create table if not exists stage_patron
(
    ID                     SERIAL primary key,
    job_id                 int references job (ID),
    institution_id         int references institution_map (ID),
    file_id                int,
    field_code             varchar,
    patron_type            varchar,
    pcode1                 varchar,
    pcode2                 varchar,
    pcode3                 varchar,
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
    note                   varchar
);

-- create table if not exists patron
-- (
--     ID             SERIAL primary key,
--     job_id         int references job (ID),
--     institution_id int references institution_map (ID)
-- --     todo: more code here, this is the final table
-- );

-- create table if not exists address
-- (
--     ID        SERIAL primary key,
--     patron_id int references patron (ID),
--     street    varchar,
--     city      varchar,
--     state     varchar,
--     zip       varchar
-- );

-- create table if not exists phone
-- (
--     ID           SERIAL primary key,
--     patron_id    int references patron (ID),
--     phone_number varchar
-- );

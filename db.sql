create table if not exists institution_map
(
    ID            SERIAL primary key,
    institution   varchar,
    folder_path   varchar,
    file_pattern  varchar,
    parser_module varchar
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
    job_id         int,
    institution_id int,
    filename       varchar
);

create table stage_patron
(
    ID                     SERIAL primary key,
    job_id                 int,
    institution_id         int,
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

create table if not exists patron_final
(
    ID SERIAL primary key
--     todo: more code here
);

create table if not exists patron_address
(
    ID        SERIAL primary key,
    patron_id int,
    street    varchar,
    city      varchar,
    state     varchar,
    zip       varchar
);

create table if not exists patron_phone
(
    ID           SERIAL primary key,
    patron_id    int,
    phone_number varchar
);
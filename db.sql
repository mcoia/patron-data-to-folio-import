create table if not exists file_mapping
(
    ID           SERIAL primary key,
    cluster      varchar,
    institution  varchar,
    file         varchar,
    file_pattern varchar
);

create table if not exists job
(
    ID         SERIAL primary key,
    start_time timestamp,
    stop_time  timestamp
);

create table if not exists patron_import_files
(
    ID          SERIAL primary key,
    job_id      int,
    cluster     varchar,
    institution varchar,
    pattern     varchar,
    filename    varchar
);

create table stage_patron
(
    ID                     SERIAL primary key,
    job_id                 int,
    cluster                varchar,
    institution            varchar,
    file                   varchar,
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

create table if not exists patron
(
    ID                     SERIAL primary key,
    job_id                 int,
    externalID             varchar,
    active                 bool,
    username               varchar,
    patronGroup            varchar,
    cluster                varchar,
    institution            varchar,
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
    firstname              varchar,
    middlename             varchar,
    lastname               varchar,
    address                varchar,
    street                 varchar,
    city                   varchar,
    state                  varchar,
    zip                    varchar,
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
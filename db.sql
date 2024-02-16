create schema if not exists patron_import;

create table if not exists patron_import.institution_map
(
    id           SERIAL primary key,
    cluster      varchar,
    institution  varchar,
    folder_path  varchar,
    file         varchar,
    file_pattern varchar,
    module       varchar
);

create table if not exists patron_import.job
(
    id         SERIAL primary key,
    start_time timestamp,
    stop_time  timestamp
);

create table if not exists patron_import.file_tracker
(
    id             SERIAL primary key,
    job_id         int references patron_import.job (id),
    institution_id int references patron_import.institution_map (id),
    filename       varchar
);

create table if not exists patron_import.stage_patron
(
    id                     SERIAL primary key,
    job_id                 int references patron_import.job (id),
    institution_id         int references patron_import.institution_map (id),
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

create table if not exists patron_import.patron
(
    id                     SERIAL primary key,
    institution_id         int references patron_import.institution_map (id),
    hashcode               int,
    loadFolio              bool,
    username               varchar,
    externalSystemId       varchar,
    barcode                varchar,
    active                 bool,
    patronGroup            varchar,
    lastName               varchar,
    firstName              varchar,
    middleName             varchar,
    preferredFirstName     varchar,
    phone                  varchar,
    mobilePhone            varchar,
    dateOfBirth            varchar,
    preferredContactTypeId varchar,
    enrollmentDate         varchar,
    expirationDate         varchar
);

create table if not exists patron_import.address
(
    id             SERIAL primary key,
    patron_id      int references patron_import.patron (id),
    countryId      varchar default 'US',
    addressLine1   varchar,
    addressLine2   varchar,
    city           varchar,
    region         varchar,
    postalCode     varchar,
    addressTypeId  varchar default 'Home',
    primaryAddress varchar
);

create table if not exists patron_import.ptype_mapping
(
    id         SERIAL primary key,
    name       varchar,
    ptype      varchar,
    foliogroup varchar
);
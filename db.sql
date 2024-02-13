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

create table if not exists patron
(
    ID                     SERIAL primary key,
    institution_id         int references institution_map (ID),
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

create table if not exists address
(
    ID             SERIAL primary key,
    patron_id      int references patron (ID),
    countryId      varchar default 'US',
    addressLine1   varchar,
    addressLine2   varchar,
    city           varchar,
    region         varchar,
    postalCode     varchar,
    addressTypeId  varchar default 'Home',
    primaryAddress varchar
);

create table if not exists ptype_mapping
(
    ID             SERIAL primary key,
    name       varchar,
    ptype      varchar,
    foliogroup varchar
);
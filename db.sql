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
    address                varchar,
    telephone              varchar,
    address2               varchar,
    telephone2             varchar,
    department             varchar,
    unique_id              varchar,
    barcode                varchar,
    email_address          varchar,
    note                   varchar,
    _firstname             varchar,
    _middlename            varchar,
    _lastname              varchar,
    _street                varchar,
    _city                  varchar,
    _state                 varchar,
    _zip                   varchar,
    file                   varchar,
    timestamp              timestamp
);

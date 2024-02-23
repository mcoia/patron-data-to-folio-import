create schema if not exists patron_import;

create table if not exists patron_import.institution_map
(
    id           SERIAL primary key,
    cluster      text,
    institution  text,
    folder_path  text,
    file         text,
    file_pattern text,
    module       text,
    esid         text
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
    filename       text
);

create table if not exists patron_import.stage_patron
(
    id                     SERIAL primary key,
    job_id                 int references patron_import.job (id),
    institution_id         int references patron_import.institution_map (id),
    file_id                int references patron_import.file_tracker (id),
    esid                   text,
    fingerprint            text,
    field_code             text,
    patron_type            text,
    pcode1                 text,
    pcode2                 text,
    pcode3                 text,
    home_library           text,
    patron_message_code    text,
    patron_block_code      text,
    patron_expiration_date text,
    name                   text,
    address                text,
    telephone              text,
    address2               text,
    telephone2             text,
    department             text,
    unique_id              text,
    barcode                text,
    email_address          text,
    note                   text
);

create table if not exists patron_import.patron
(
    id                     SERIAL primary key,
    institution_id         int references patron_import.institution_map (id),
    fingerprint            text,
    loadFolio              bool not null default false,
    username               text,
    externalSystemId       text,
    barcode                text,
    active                 bool not null default true,
    patronGroup            text,
    lastName               text,
    firstName              text,
    middleName             text,
    preferredFirstName     text,
    phone                  text,
    mobilePhone            text,
    dateOfBirth            text,
    preferredContactTypeId text,
    enrollmentDate         text,
    expirationDate         text
);

create table if not exists patron_import.address
(
    id             SERIAL primary key,
    patron_id      int references patron_import.patron (id),
    countryId      text default 'US',
    addressLine1   text,
    addressLine2   text,
    city           text,
    region         text,
    postalCode     text,
    addressTypeId  text default 'Home',
    primaryAddress text
);

create table if not exists patron_import.ptype_mapping
(
    id         SERIAL primary key,
    name       text,
    ptype      text,
    foliogroup text
);


create function patron_import.zeroPadTrunc(pt text) returns text
    language plpgsql
as
$$
DECLARE
    ptext text;
BEGIN
    ptext := regexp_replace(pt, '^0*', '', 'g');
    RETURN BTRIM(ptext);
END;
$$;

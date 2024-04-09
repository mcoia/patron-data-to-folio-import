create schema if not exists patron_import;

create table if not exists patron_import.institution
(
    id      SERIAL primary key,
    enabled bool default true,
    name    text,
    module  text,
    esid    text
);

create table if not exists patron_import.folder
(
    id   SERIAL primary key,
    path text
);

create table if not exists patron_import.institution_folder_map
(
    id             SERIAL primary key,
    institution_id int references patron_import.institution (id),
    folder_id      int references patron_import.folder (id)
);

create table if not exists patron_import.file
(
    id             SERIAL primary key,
    institution_id int references patron_import.institution (id),
    name           text,
    pattern        text
);

create table if not exists patron_import.job
(
    id         SERIAL primary key,
    job_type   text,
    start_time timestamp,
    stop_time  timestamp
);

create table if not exists patron_import.file_tracker
(
    id             SERIAL primary key,
    job_id         int references patron_import.job (id),
    institution_id int references patron_import.institution (id),
    path           text,
    size           int,
    lastModified   int
);

create table if not exists patron_import.stage_patron
(
    id                     SERIAL primary key,
    job_id                 int references patron_import.job (id),
    institution_id         int references patron_import.institution (id),
    file_id                int references patron_import.file (id),
    load                   bool not null default false,
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
    address                text, -- todo: rename this to dollar_sign_address    text,
    telephone              text,
    address2               text,
    telephone2             text,
    department             text,
    unique_id              text,
    barcode                text,
    email_address          text,
    note                   text,
    zeroline               text
);

create table if not exists patron_import.patron
(
    id                     SERIAL primary key,
    institution_id         int references patron_import.institution (id),
    file_id                int references patron_import.file (id),
    job_id                 int references patron_import.job (id),
    fingerprint            text,
    ready                  bool not null default true,
    error                  bool not null default false,
    errorMessage           text,
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
    primaryAddress bool default true
);

create table if not exists patron_import.ptype_mapping
(
    id             SERIAL primary key,
    institution_id int references patron_import.institution (id),
    ptype          text,
    foliogroup     text
);

CREATE INDEX IF NOT EXISTS patron_import_stage_patron_unique_id_idx ON patron_import.stage_patron USING btree (unique_id);

CREATE OR REPLACE FUNCTION patron_import.address_trigger_function()
    RETURNS trigger AS

$$
DECLARE
    originalAddress text;
    _addressLine1   text;
    _addressLine2   text;
    _city           text;
    _region         text;
    _postalcode     text;

BEGIN

    SELECT INTO originalAddress address
    FROM patron_import.stage_patron sp
    WHERE sp.unique_id = NEW.username
      AND sp.address IS NOT NULL
      AND btrim(sp.address) != ''
      AND sp.load
    LIMIT 1;

    IF NOT FOUND THEN RETURN NEW; END IF;
    -- short circuit when address is null or empty

    SELECT INTO _addressLine2 address2
    FROM patron_import.stage_patron sp
    WHERE sp.unique_id = NEW.username
    LIMIT 1;

    IF originalAddress ~ '\$' THEN
        _addressLine1 := btrim(split_part(originalAddress, '$', 1));
        originalAddress := btrim(split_part(originalAddress, '$', 2));
    END IF;

    _city := btrim(split_part(originalAddress, ',', 1));
    originalAddress := btrim(split_part(originalAddress, ',', 2));

    _region := btrim(split_part(originalAddress, ' ', 1));
    _postalcode := btrim(split_part(originalAddress, ' ', 2));

    -- TGOP = UPDATE
    IF TG_OP = 'UPDATE' THEN

        -- general update statement here
        UPDATE patron_import.address
        SET addressLine1 = _addressLine1,
            addressLine2 = _addressline2,
            city         = _city,
            region       = _region,
            postalcode   = _postalcode
        WHERE patron_id = NEW.id;

    ELSIF TG_OP = 'INSERT' THEN

        INSERT INTO patron_import.address (patron_id, addressline1, addressline2, city, region, postalcode)
        VALUES (NEW.id, _addressLine1, _addressLine2, _city, _region, _postalcode);
    END IF;

    RETURN NEW;

END;

$$
    LANGUAGE 'plpgsql';

CREATE TRIGGER address_trigger
    AFTER INSERT OR UPDATE
    ON patron_import.patron
    FOR EACH ROW
EXECUTE PROCEDURE patron_import.address_trigger_function();

CREATE OR REPLACE FUNCTION patron_import.zeroPadTrunc(pt text) returns text
    LANGUAGE plpgsql
as
$$
DECLARE
    ptext text;
BEGIN
    ptext := regexp_replace(pt, '^0*', '', 'g');
    RETURN BTRIM(ptext);
END;
$$;

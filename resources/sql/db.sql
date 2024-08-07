create schema if not exists patron_import;

create table if not exists patron_import.institution
(
    id           SERIAL primary key,
    enabled      bool default true,
    name         text,
    tenant       text,
    module       text,
    esid         text,
    emailSuccess text,
    emailFail    text
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
    lastModified   int,
    contents       text
);

create table if not exists patron_import.stage_patron
(
    id                     SERIAL primary key,
    job_id                 int references patron_import.job (id),
    institution_id         int references patron_import.institution (id),
    file_id                int references patron_import.file (id),
    load                   bool not null default true,
    raw_data               text,
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
    note                   text,
    preferred_name         text
);

create table if not exists patron_import.patron
(
    id                     SERIAL primary key,
    institution_id         int references patron_import.institution (id),
    file_id                int references patron_import.file (id),
    job_id                 int references patron_import.job (id),
    fingerprint            text,
    ready                  bool not null default true,
    raw_data               text,

    -- dates
    insert_date            timestamp     default now(),
    update_date            timestamp     default null,
    load_date              timestamp     default null,

    -- json specific below
    username               text,
    externalsystemid       text,
    barcode                text,
    email                  text,
    active                 bool not null default true,
    patrongroup            text,
    lastname               text,
    firstname              text,
    middlename             text,
    preferredfirstname     text,
    phone                  text,
    mobilephone            text,
    dateofbirth            text,
    preferredcontacttypeid text,
    enrollmentdate         text,
    expirationdate         text
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
    foliogroup     text,
    priority       int
);

alter table patron_import.ptype_mapping
    add constraint ptype_mapping_priority_unique unique (institution_id, priority);

create table if not exists patron_import.login
(
    id             SERIAL primary key,
    institution_id int references patron_import.institution (id),
    username       text,
    password       text
);

create table if not exists patron_import.import_response
(
    id             SERIAL primary key,
    institution_id int references patron_import.institution (id),
    job_id         int references patron_import.job (id),
    message        text,
    created        int,
    updated        int,
    failed         int,
    total          int
);

create table if not exists patron_import.import_failed_users
(
    id                 SERIAL primary key,
    import_response_id int references patron_import.import_response (id),
    externalSystemId   text,
    username           text,
    errorMessage       text
);

create table if not exists patron_import.import_failed_users_json
(
    id                 SERIAL primary key,
    import_response_id int references patron_import.import_response (id),
    json               jsonb
);

CREATE INDEX IF NOT EXISTS patron_import_institution_id_idx ON patron_import.institution USING btree (id);
CREATE INDEX IF NOT EXISTS patron_import_stage_patron_unique_id_idx ON patron_import.stage_patron USING btree (unique_id);
CREATE INDEX IF NOT EXISTS patron_import_patron_fingerprint_idx ON patron_import.patron USING btree (fingerprint);
CREATE INDEX IF NOT EXISTS patron_import_patron_external_system_id_idx ON patron_import.patron USING btree (externalsystemid);
CREATE INDEX IF NOT EXISTS patron_import_patron_username_idx ON patron_import.patron USING btree (username);
CREATE INDEX IF NOT EXISTS patron_import_ptype_mapping_foliogroup ON patron_import.ptype_mapping USING btree (foliogroup);

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
    WHERE btrim(lower(sp.unique_id)) = btrim(lower(NEW.username))
      AND sp.address IS NOT NULL
      AND btrim(sp.address) != ''
      AND sp.load
    LIMIT 1;

    IF NOT FOUND THEN RETURN NEW; END IF;
    -- short circuit when address is null or empty

    SELECT INTO _addressLine2 address2
    FROM patron_import.stage_patron sp
    WHERE btrim(lower(sp.unique_id)) = btrim(lower(NEW.username))
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
            postalCode   = _postalcode
        WHERE patron_id = NEW.id;

    ELSIF TG_OP = 'INSERT' THEN

        INSERT INTO patron_import.address (patron_id, addressLine1, addressLine2, city, region, postalCode)
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

CREATE OR REPLACE FUNCTION patron_import.ptype_mapping_trigger_function() RETURNS trigger
    LANGUAGE plpgsql
AS
$$

BEGIN

    IF NEW.foliogroup IS NOT NULL THEN

        UPDATE patron_import.patron patron
        SET patrongroup = NEW.foliogroup,
            ready       = true
        WHERE coalesce(NULLif(ltrim(SUBSTRING((patron.raw_data), 2, 3), '0'), ''), '0') = NEW.ptype
          AND NEW.institution_id = patron.institution_id
          AND (patron.patrongroup IS NULL OR patron.patrongroup != NEW.foliogroup);


        UPDATE patron_import.patron patron
        SET patrongroup = NULL
        FROM patron_import.patron p2
                 LEFT JOIN patron_import.ptype_mapping pt
                           on (coalesce(NULLif(ltrim(SUBSTRING((p2.raw_data), 2, 3), '0'), ''), '0') = pt.ptype and
                               pt.institution_id = p2.institution_id)
        WHERE patron.id = p2.id
          AND pt.id is null
          AND p2.patrongroup IS NOT NULL;

    END IF;

    RETURN NEW;
END;
$$;

alter function patron_import.ptype_mapping_trigger_function() owner to postgres;

CREATE TRIGGER ptype_mapping_trigger
    AFTER INSERT OR UPDATE
    ON patron_import.ptype_mapping
    FOR EACH ROW
EXECUTE PROCEDURE patron_import.ptype_mapping_trigger_function();

CREATE OR REPLACE FUNCTION patron_import.update_date_trigger_function()
    RETURNS trigger AS
$$
BEGIN
    NEW.update_date = NOW();
    RETURN NEW;
END;
$$
    LANGUAGE 'plpgsql';

CREATE TRIGGER update_date_trigger
    BEFORE UPDATE
    ON patron_import.patron
    FOR EACH ROW
EXECUTE PROCEDURE patron_import.update_date_trigger_function();

-- this needs testing .
-- CREATE OR REPLACE FUNCTION patron_import.date_checker( datestring TEXT )
--     RETURNS TEXT AS
-- $BODY$
-- DECLARE
--     return_string       TEXT;
-- BEGIN
--     return_string := datestring::DATE::TEXT;
-- EXCEPTION WHEN OTHERS THEN RETURN NULL;
-- RETURN return_string;
-- END;
-- $BODY$
--     LANGUAGE PLPGSQL;

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
    address1_one_liner     text,
    address2_one_liner     text,

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
    addressTypeId  text default 'Address 1',
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

CREATE TYPE patron_import.address_unit AS
(
    line1 TEXT,
    line2 TEXT,
    city  TEXT,
    state TEXT,
    zip   TEXT,
    valid BOOLEAN
);

CREATE OR REPLACE FUNCTION patron_import.parse_city_state_zip_liner_address(one_liner TEXT)
    RETURNS patron_import.address_unit AS
$BODY$
DECLARE
    result patron_import.address_unit;
BEGIN
    IF one_liner IS NULL THEN
        result.valid := FALSE;
        RETURN result;
    END IF;
    result.city := btrim(split_part(one_liner, ',', 1));
    -- RAISE NOTICE '%', result.city;
    one_liner := btrim(right(one_liner, (length(result.city) + 1) * -1));

    -- RAISE NOTICE '%', one_liner;
    -- Make multiple spaces single spaces
    one_liner := regexp_replace(one_liner, '\s+', ' ', 'g');
    -- RAISE NOTICE '%', one_liner;

    result.state := btrim(split_part(one_liner, ' ', 1));
    -- the zipcode gets the rest of the string
    result.zip := btrim(right(one_liner, (length(result.state) + 1) * -1));

    RETURN result;
END;
$BODY$
    LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION patron_import.parse_one_liner_address(one_liner TEXT)
    RETURNS patron_import.address_unit AS
$BODY$
DECLARE
    result         patron_import.address_unit;
    city_state_zip patron_import.address_unit;
    loopres        TEXT;
    section_count  INT;
BEGIN

    -- assume invalid by default
    result.valid := FALSE;

    IF one_liner IS NULL THEN
        RETURN result;
    END IF;

    -- RAISE NOTICE '%', one_liner;
    -- double dollar signs need reduced to single
    one_liner := regexp_replace(one_liner, '\$+', '$', 'g');
    -- RAISE NOTICE 'after double->single %', one_liner;

    -- Short circuit when not enough data
    IF LENGTH(BTRIM(one_liner)) < 2 THEN
        return result;
    END IF;

    -- Figure out how many dollar signs there are
    SELECT INTO section_count count(*) from regexp_matches(one_liner, '\$', 'g');

    IF section_count > 0 THEN
        result.line1 := btrim(split_part(one_liner, '$', 1));
        -- RAISE NOTICE '%', result.line1;
        one_liner := btrim(right(one_liner, (length(result.line1) + 1) * -1));
    END IF;

    -- case when address has line1 and line2
    IF section_count > 1 THEN
        result.line2 := '';
    END IF;

    WHILE one_liner ~ '\$'
        LOOP
            loopres := btrim(split_part(one_liner, '$', 1));
            result.line2 := result.line2 || ' ' || loopres;
            -- RAISE NOTICE '%', result.line2;
            one_liner := btrim(right(one_liner, (length(loopres) + 1) * -1));
        END LOOP;
    result.line2 := regexp_replace(result.line2, '\s+', ' ', 'g');

    -- get the city, state, zip from what's left
    city_state_zip := patron_import.parse_city_state_zip_liner_address(one_liner);

    result.city := city_state_zip.city;
    result.state := city_state_zip.state;
    result.zip := city_state_zip.zip;

    result.valid := TRUE;
    RETURN result;
END;
$BODY$
    LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION patron_import.address_trigger_function()
    RETURNS trigger AS
$$
DECLARE
    incoming_addresses patron_import.address_unit[];
    test_address       patron_import.address_unit;
    one_liner          TEXT;
    array_setup        TEXT[];
    primary_address    BOOLEAN := TRUE;
    address_type       TEXT := 'Address 1';

BEGIN

    array_setup := ('{"' || regexp_replace(COALESCE(NEW.address1_one_liner::TEXT, ''), '"', ' ', 'g') || '","' ||
                    regexp_replace(COALESCE(NEW.address2_one_liner::TEXT, ''), '"', ' ', 'g') || '"}')::TEXT[];
    FOREACH one_liner IN ARRAY array_setup
        LOOP
            test_address := patron_import.parse_one_liner_address(one_liner);
            IF test_address.valid
            THEN
                incoming_addresses := array_append(incoming_addresses, test_address);
            END IF;
        END LOOP;

    IF array_upper(incoming_addresses, 1) IS NOT NULL
    THEN
        IF TG_OP = 'UPDATE' THEN
            -- REMOVE all previous addresses, in favor of the new one coming in
            DELETE FROM patron_import.address WHERE patron_id = NEW.id;
        END IF;

        FOREACH test_address IN ARRAY incoming_addresses
            LOOP
                INSERT INTO patron_import.address (patron_id, addressLine1, addressLine2, city, region, postalCode,
                                                   primaryaddress, addressTypeId)
                VALUES (NEW.id, test_address.line1, test_address.line2, test_address.city, test_address.state,
                        test_address.zip, primary_address, address_type);
                -- only the first address is primary, the rest are secondary+
                primary_address := FALSE;
                address_type := 'Address 2';
            END LOOP;
    END IF;
    RETURN NEW;
END;

$$
    LANGUAGE 'plpgsql';

CREATE OR REPLACE FUNCTION patron_import.populate_address_from_raw(patron_id INT)
    RETURNS VOID AS
$$
DECLARE
    address1 TEXT;
    address2 TEXT;
BEGIN
    SELECT INTO address1 right(tline, -1)
    FROM (select regexp_split_to_table(raw_data, '[\n\r]') AS "tline"
          FROM patron_import.patron
          WHERE id = patron_id) as alll
    where alll.tline ~ '^a'
    LIMIT 1;

    SELECT INTO address2 right(tline, -1)
    FROM (select regexp_split_to_table(raw_data, '[\n\r]') AS "tline"
          FROM patron_import.patron
          WHERE id = patron_id) as alll
    where alll.tline ~ '^h'
    limit 1;

    if address1 = address2
    then
        raise notice 'addresses are equal';
        address2 := null;
    end if;

    if address1 is not null
    then
        update patron_import.patron
        set address1_one_liner = address1
        where id = patron_id;
    else
        update patron_import.patron
        set address1_one_liner = NULL
        WHERE id = patron_id;
    END IF;

    IF address2 IS NOT NULL
    THEN
        UPDATE patron_import.patron
        SET address2_one_liner = address2
        WHERE id = patron_id;
    ELSE
        update patron_import.patron
        set address2_one_liner = NULL
        WHERE id = patron_id;
    END IF;
END;
$$
    LANGUAGE 'plpgsql';

CREATE OR REPLACE TRIGGER address_trigger
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

CREATE OR REPLACE TRIGGER ptype_mapping_trigger
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

CREATE OR REPLACE TRIGGER update_date_trigger
    BEFORE UPDATE
    ON patron_import.patron
    FOR EACH ROW
EXECUTE PROCEDURE patron_import.update_date_trigger_function();

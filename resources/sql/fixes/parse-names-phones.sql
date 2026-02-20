-- Fix: Parse preferred names and phone numbers from raw data
-- Run periodically to repair patron records with missing data

BEGIN;

----------------------------------------
-- Update preferred names from raw
UPDATE patron_import.patron p
SET ready              = true,
    preferredfirstname = CASE
        -- Set preferredfirstname to the result of the regexp_match function
                             WHEN (regexp_match(p.raw_data, '^s(.*)$', 'm'))[1] IS NOT NULL
                                 AND p.preferredfirstname IS NULL
                                 AND (regexp_match(p.raw_data, '^s(.*)$', 'm'))[1] LIKE '%,%' THEN
                                 -- Extract the substring when there is a comma in the match
                                 SUBSTRING((regexp_match(p.raw_data, '^s(.*)$', 'm'))[1] FROM ',(.*)')
                             ELSE p.preferredfirstname -- Retain current value if no match or no comma
        END
WHERE p.preferredfirstname IS NULL
    AND (regexp_match(p.raw_data, '^s(.*)$', 'm'))[1] IS NOT NULL
    AND (regexp_match(p.raw_data, '^s(.*)$', 'm'))[1] LIKE '%,%'
   OR (p.preferredfirstname IS NOT NULL
    AND p.preferredfirstname != SUBSTRING((regexp_match(p.raw_data, '^s(.*)$', 'm'))[1] FROM ', (.*) '));



-- Update preferred names from raw where the ^s is present but the preferredfirstname is null
UPDATE patron_import.patron p
SET preferredfirstname = TRIM((regexp_match(p.raw_data, '^s(.*)$', 'm'))[1]),
    ready              = true
WHERE
    p.preferredfirstname IS NULL
  AND (regexp_match(p.raw_data, '^s(.*)$', 'm'))[1] IS NOT NULL
  AND TRIM((regexp_match(p.raw_data, '^s(.*)$', 'm'))[1]) != '';


----------------------------------------
-- Update phone numbers from raw
UPDATE patron_import.patron p
SET ready       = true,
    phone       = CASE
                      WHEN subquery.phone_number IS NOT NULL THEN subquery.phone_number
                      ELSE p.phone
        END,
    mobilephone = CASE
                      WHEN subquery.mobile_number IS NOT NULL THEN subquery.mobile_number
                      ELSE p.mobilephone
        END
FROM (SELECT id,
             (regexp_matches(raw_data, '^t(.*)$', 'm'))[1] AS phone_number,
             (regexp_matches(raw_data, '^p(.*)$', 'm'))[1] AS mobile_number
      FROM patron_import.patron) subquery
WHERE p.id = subquery.id
  AND ((subquery.phone_number IS NOT NULL AND p.phone != subquery.phone_number) OR
       (subquery.mobile_number IS NOT NULL AND p.mobilephone != subquery.mobile_number));



COMMIT;
-- ROLLBACK;

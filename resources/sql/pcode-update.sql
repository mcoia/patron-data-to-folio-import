create table patron_import.pcode1_mapping (id SERIAL primary key, institution_id int references patron_import.institution (id), pcode1 text, pcode1_value text);
create table patron_import.pcode2_mapping (id SERIAL primary key, institution_id int references patron_import.institution (id), pcode2 text, pcode2_value text);
create table patron_import.pcode3_mapping (id SERIAL primary key, institution_id int references patron_import.institution (id), pcode3 text, pcode3_value text);


-- Sierra PCODE2 code	FOLIO Class Level
-- f	FRESHMAN
-- g	GRADUATE
-- h	HIGH SCHOOL
-- j	JUNIOR
-- r	SENIOR
-- s 	SOPHOMORE
-- -	NONE
INSERT INTO pcode2_mapping (institution_id, pcode2, pcode2_value) VALUES (47, 'f', 'FRESHMAN');
INSERT INTO pcode2_mapping (institution_id, pcode2, pcode2_value) VALUES (47, 'g', 'GRADUATE');
INSERT INTO pcode2_mapping (institution_id, pcode2, pcode2_value) VALUES (47, 'h', 'HIGH SCHOOL');
INSERT INTO pcode2_mapping (institution_id, pcode2, pcode2_value) VALUES (47, 'j', 'JUNIOR');
INSERT INTO pcode2_mapping (institution_id, pcode2, pcode2_value) VALUES (47, 'r', 'SENIOR');
INSERT INTO pcode2_mapping (institution_id, pcode2, pcode2_value) VALUES (47, 's', 'SOPHOMORE');
INSERT INTO pcode2_mapping (institution_id, pcode2, pcode2_value) VALUES (47, '-', 'NONE');

-- Sierra PCODE3 code	FOLIO Departments Code
-- 103	ACAFF
-- 1	ACCT
-- 2	ADMIN
-- 10	ART
-- 12	BIOL
-- 15	CHEM
-- 17	COMM
-- 18	CMPS
-- 21	CONED
-- 23	CRJ
-- 28	ECON
-- 30	EDEL
-- 31	EDGN
-- 40	ENGR
-- 37	ENGL
-- 104	FINEART
-- 47	BUS
-- 105	HLTH
-- 53	HIST
-- 69	MATH
-- 77	MUSIC
-- 79	NURS
-- 82	PHYSED
-- 84	PTASST
-- 88	PSYCH
-- 0	UNDC

INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '103', 'ACAFF');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '1', 'ACCT');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '2', 'ADMIN');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '10', 'ART');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '12', 'BIOL');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '15', 'CHEM');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '17', 'COMM');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '18', 'CMPS');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '21', 'CONED');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '23', 'CRJ');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '28', 'ECON');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '30', 'EDEL');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '31', 'EDGN');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '40', 'ENGR');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '37', 'ENGL');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '104', 'FINEART');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '47', 'BUS');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '105', 'HLTH');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '53', 'HIST');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '69', 'MATH');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '77', 'MUSIC');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '79', 'NURS');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '82', 'PHYSED');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '84', 'PTASST');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '88', 'PSYCH');
INSERT INTO patron_import.pcode3_mapping (institution_id, pcode3, pcode3_value) VALUES (47, '0', 'UNDC');

-- Add note column to patron table
ALTER TABLE patron_import.patron ADD COLUMN note text;

-- Create the indexes for the mapping tables
-- CREATE INDEX idx_pcode1_mapping_institution_id ON pcode1_mapping (institution_id);
-- CREATE INDEX idx_pcode2_mapping_institution_id ON pcode2_mapping (institution_id);
-- CREATE INDEX idx_pcode3_mapping_institution_id ON pcode3_mapping (institution_id);
-- CREATE INDEX idx_pcode2_mapping_pcode2 ON pcode2_mapping (pcode2);
-- CREATE INDEX idx_pcode3_mapping_pcode3 ON pcode3_mapping (pcode3);









INSERT INTO patron_import.pcode2_mapping (institution_id, pcode2, pcode2_value) VALUES (47, 'f', 'FRESHMAN');
INSERT INTO patron_import.pcode2_mapping (institution_id, pcode2, pcode2_value) VALUES (47, 'g', 'GRADUATE');
INSERT INTO patron_import.pcode2_mapping (institution_id, pcode2, pcode2_value) VALUES (47, 'h', 'HIGH SCHOOL');
INSERT INTO patron_import.pcode2_mapping (institution_id, pcode2, pcode2_value) VALUES (47, 'j', 'JUNIOR');
INSERT INTO patron_import.pcode2_mapping (institution_id, pcode2, pcode2_value) VALUES (47, 'r', 'SENIOR');
INSERT INTO patron_import.pcode2_mapping (institution_id, pcode2, pcode2_value) VALUES (47, 's', 'SOPHOMORE');
INSERT INTO patron_import.pcode2_mapping (institution_id, pcode2, pcode2_value) VALUES (47, '-', 'NONE');
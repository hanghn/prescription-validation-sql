DROP DATABASE IF EXISTS ade;
CREATE DATABASE  IF NOT EXISTS ade;
USE ade;


-- DISEASE

DROP TABLE IF EXISTS disease;
CREATE TABLE disease (
  disease_id int(11) PRIMARY KEY,
  disease_name varchar(100) DEFAULT NULL
) ;

INSERT INTO disease VALUES 
(1,'Cold'),
(2,'Flu'),
(3,'Typhus'), 
(4, 'The plague'), 
(5, 'Flesh-eating bacteria');


-- SPECIALTY
DROP TABLE IF EXISTS  specialty;
CREATE TABLE specialty (
	specialty_id INT PRIMARY KEY AUTO_INCREMENT,
    specialty_name VARCHAR(20)
);

INSERT INTO specialty (specialty_name) VALUES
('GENERAL PRACTITIONER'),
('CARDIOLOGY'),
('UROLOGY'),
('DIAGNOSTICS'),
('BRAIN SURGERY'),
('INTERNAL MEDICINE');



-- DOCTOR

DROP TABLE IF EXISTS doctor;
CREATE TABLE doctor (
  doctor_id int(11) PRIMARY KEY,
  doctor_name varchar(100) DEFAULT NULL,
  specialty_id INT NULL,
  CONSTRAINT fk_doctor_spec FOREIGN KEY (specialty_id) REFERENCES specialty (specialty_id)
) ;

INSERT INTO doctor VALUES 
(1,'Dr.Marcus', 5),
(2,'Dr.House', 4),
(3,'Dr.Howser', 1),
(4,'Dr.Quinn', 1),
 (5, 'Dr.Oz', 2),
 (6, 'Dr.McCoy', null),
 (7, 'Dr.Cooper', 1),
 (8, 'Dr.Crusher', 4);

-- PATIENT

DROP TABLE IF EXISTS patient;
CREATE TABLE patient (
  patient_id int(11) PRIMARY KEY,
  patient_name varchar(100) DEFAULT NULL,
  sex char(1) DEFAULT NULL,
  is_pregnant tinyint(1) DEFAULT FALSE,
  flushot tinyint(1) DEFAULT NULL,
  state char(2) DEFAULT NULL,
  dob date DEFAULT NULL,
  height float DEFAULT NULL,
  weight float DEFAULT NULL,
  pcp_id int(11) NOT NULL,
  
  CONSTRAINT fk_patient_pcp FOREIGN KEY (pcp_id) REFERENCES doctor (doctor_id)

);


INSERT INTO patient VALUES 
(1,'Smith','M',0,1,'VT','1995-01-22',72,240,3),
(2,'Jones','F',1,0,'MA','1964-12-29',71.5,160,3),
(3,'Johnson','F', 0,1,'MA','1922-04-22',65,130,3),
(4,'Phillips','F',0,1,'MA','1999-11-11',61,116,3),
(5,'Lee','M', 0, 1,'CT','1970-10-08',73,240,3),
(6,'Williams','M', 0, 0,'NY','1966-07-04',70,150,4),
(7,'Samuels','F', 0, 1,'CA','1969-08-11',68,130,4),
(8,'van Dyke','M', 0, 1,'CA','1978-03-27',71,165,4),
(9,'BillyTheKid', 'M', 0, 1, 'MA','2015-08-11', 36, 55,4);


-- DIAGNOSIS

DROP TABLE IF EXISTS diagnosis;
CREATE TABLE diagnosis (
  doctor_id int(11) DEFAULT NULL,
  patient_id int(11) DEFAULT NULL,
  disease_id int(11) DEFAULT NULL,
  diagnosis_date date DEFAULT NULL,
  CONSTRAINT fk_diag_doc FOREIGN KEY (doctor_id) REFERENCES doctor (doctor_id),
  CONSTRAINT fk_diag_pat  FOREIGN KEY (patient_id) REFERENCES patient (patient_id),
  CONSTRAINT fk_diag_dis FOREIGN KEY (disease_id) REFERENCES disease (disease_id)
) ;

INSERT INTO diagnosis VALUES 
(1,1,1, '2016-01-11'),
(1,1,3, '2016-11-22'),
(3,1,1, '2017-05-15'),
(1,2,2, '2017-03-19'),
(3,2,2, '2016-02-23'),
(1,2,1, '2016-06-04'),
(2,3,1, '2016-09-12'),
(2,3,2, '2017-04-15'),
(2,4,1, '2016-03-30'),
(4,4,3, '2016-08-31'),
(2,5,2, '2016-01-08'),
(2,6,2, '2017-11-01'),
(3,7,2, '2016-06-19');



-- RECOMMENDATIONS

DROP TABLE IF EXISTS recommendation;
CREATE TABLE recommendation (
  patient_id int(11)  NOT NULL,
  message varchar(255) NOT NULL,
  CONSTRAINT fk_recommendations FOREIGN KEY (patient_id) REFERENCES patient (patient_id)
) ;

insert into recommendation values
(2, 'Take pre-natal vitamins'),
(5, 'Encourage patient to diet and exercise'),
(2, 'Ask patient if he/she has had a flushot'),
(6, 'Ask patient if he/she has had a flushot');


-- Step 1. Create and populate a medications table

drop table if exists medication;
create table medication (
	medication_id INT PRIMARY KEY,
    medication_name VARCHAR(255) UNIQUE,
    take_under_12 BOOLEAN  DEFAULT False,
    take_if_pregnant BOOLEAN DEFAULT False,
    mg_per_pill DOUBLE,
    max_mg_per_10kg DOUBLE
);

insert into medication values
(1, 'Remembera', False, True, 10.0, 4.0),
(2, 'Forgeta', True, False, 20.0, 5.0),
(3, 'Happyza', True, True, 30.0, 10.0),
(4, 'Sadza', True, False, 75.0, 20.0),
(5, 'Panecea', True, True, 100.0, 20.0),
(6, 'Placebo', True, True, 50.0, 15.0),
(7, 'Muscula', False, True, 25.0, 8.0),
(8, 'Mygrane', True, True, 100.0, 30.0),
(9, 'Foobaral', True, False, 300.0, 75.0),
(10, 'Spektora', True, True, 10.0, 3.0);



-- Step 2. A table of medications that should not be taken together due
-- to possible drug-drug interactions
-- To make our code simpler, we'll list both directions as two separate records

drop table if exists interaction;
create table interaction (
	medication_1 INT,
    medication_2 INT,
    CONSTRAINT fk_interaction_med1 FOREIGN KEY (medication_1) REFERENCES medication (medication_id),
    CONSTRAINT fk_interaction_med2 FOREIGN KEY (medication_2) REFERENCES medication (medication_id)
);


insert into interaction values
(1,2),(2,1), -- Remembera and Forgeta can't be taken together
(3,4),(4,3); -- Happyza and Sadza can't be taken together





-- Step 3. A prescription table to store prescriptions

drop table if exists prescription;
create table prescription (
	medication_id int,
    patient_id int,
    doctor_id int,
    prescription_dt datetime default now(),
    ppd int, -- pills per day
    CONSTRAINT fk_prescription_medication FOREIGN KEY (medication_id) REFERENCES medication (medication_id),
    CONSTRAINT fk_prescription_patient FOREIGN KEY (patient_id) REFERENCES patient (patient_id),
    CONSTRAINT fk_prescription_doctor FOREIGN KEY (doctor_id) REFERENCES doctor (doctor_id)
);


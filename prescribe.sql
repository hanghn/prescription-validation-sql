-- Prescription validation engine
-- Stored procedure + trigger to enforce clinical safety rules at the database layer:
--   1. Pediatric safety       -- block meds not approved for children under 12
--   2. Pregnancy safety       -- block meds not safe during pregnancy
--   3. Drug-drug interactions -- block meds that conflict with active prescriptions
--
-- Run schema.sql first to create the `ade` database and seed test data.

use ade;


-- A stored procedure to process and validate prescriptions
-- Four things we need to check
-- a) Is patient a child and is medication suitable for children?
-- b) Is patient pregnant and is medication suitable for pregnant women?
-- c) Are there any adverse drug reactions


drop procedure if exists prescribe; 

delimiter //
create procedure prescribe
(
    in patient_name_param varchar(255),
    in doctor_name_param varchar(255),
    in medication_name_param varchar(255),
    in ppd_param int -- pills per day prescribed
)
begin
	-- variable declarations
    declare patient_id_var int;
    declare age_var float;
    declare is_pregnant_var boolean;
    declare weight_var int;
    declare doctor_id_var int;
    declare medication_id_var int;
    declare take_under_12_var boolean;
    declare take_if_pregnant_var boolean;
    declare mg_per_pill_var double;
    declare max_mg_per_10kg_var double;

    declare message varchar(255); -- The error message
    declare ddi_medication varchar(255); -- The name of a medication involved in a drug-drug interaction
    
    declare cur_medication_id INT;
    declare interaction_found boolean default false;
    
    declare medication_cursor cursor for
    select medication_id
    from prescription 
    where patient_id = patient_id_var;
    declare continue handler for not found set interaction_found = true;

    -- select relevant values into variables
    -- fetch patient, doctor, and medication IDs
    select patient_id 
    into patient_id_var 
    from patient 
    where patient_name = patient_name_param;
    
    select doctor_id 
    into doctor_id_var 
    from doctor 
    where doctor_name = doctor_name_param;
    
    select medication_id 
    into medication_id_var 
    from medication 
    where medication_name = medication_name_param;

    -- fetch the age of patient and their pregnancy status
    select timestampdiff(year, dob, curdate()), is_pregnant 
    into age_var, is_pregnant_var
    from patient where patient_name = patient_name_param;

    -- Fetch medication suitability for children and pregnant women
    select take_under_12, take_if_pregnant 
    into take_under_12_var, take_if_pregnant_var
    from medication where medication_id = medication_id_var;

    -- Check age of patient 
if age_var < 12 and take_under_12_var = false then
	set message = concat(medication_name_param, ' cannot be prescribed to children under 12.');
	signal sqlstate '45000' set message_text = message;
end if;

    -- check if medication ok for pregnant women
if is_pregnant_var and take_if_pregnant_var = false then
    set message = concat(medication_name_param, ' cannot be prescribed to pregnant women.');
    signal sqlstate '45000' set message_text = message;
end if;

    -- Check for reactions involving medications already prescribed to patient
open medication_cursor;

fetch medication_cursor into cur_medication_id;

while interaction_found = false do
    -- Check for interactions with cur_medication_id
    if exists (
        select 1
        from interaction
        where (medication_1 = cur_medication_id and medication_2 = medication_id_var) 
           or (medication_1 = medication_id_var and medication_2 = cur_medication_id)
    ) then
        -- Fetch the name of the interacting medication
        select medication_name into ddi_medication from medication where medication_id = cur_medication_id;
        set message = concat(medication_name_param, ' interacts with ', ddi_medication, ' currently prescribed to ', patient_name_param, '.');
		signal sqlstate '45000' set message_text = message;
        set interaction_found = true;
    end if;
    if not interaction_found then
        fetch medication_cursor into cur_medication_id;
    end if;
end while;

close medication_cursor;

    -- No exceptions thrown, so insert the prescription record
if not interaction_found then
    insert into prescription (patient_id, doctor_id, medication_id, ppd)
    values (patient_id_var, doctor_id_var, medication_id_var, ppd_param);
end if;

end //

delimiter;

-- Trigger

DROP TRIGGER IF EXISTS patient_after_update_pregnant;

DELIMITER //

CREATE TRIGGER patient_after_update_pregnant
	AFTER UPDATE ON patient
	FOR EACH ROW
BEGIN

    -- Patient became pregnant
    -- Add pre-natal recommenation
    -- Delete any prescriptions that shouldn't be taken if pregnant
 if old.is_pregnant != new.is_pregnant then
        if new.is_pregnant then
            -- Add pre-natal recommenation
            insert into recommendation (patient_id, message) 
            values (new.patient_id, 'Take pre-natal vitamins');
            -- Delete any prescriptions that shouldn't be taken if pregnant
            delete p from prescription p
            join medication m on p.medication_id = m.medication_id
            where p.patient_id = new.patient_id and m.take_if_pregnant = false;
        else

    -- Patient is no longer pregnant
    -- Remove pre-natal recommendation
delete from recommendation where patient_id = new.patient_id and message = 'Take pre-natal vitamins';
        end if;
    end if;

END //

DELIMITER ;



-- ------------------------------------------------------------------------------
--                                  TEST CASES
-- ------------------------------------------------------------------------------
truncate prescription;

-- These prescriptions should succeed
call prescribe('Jones', 'Dr.Marcus', 'Happyza', 2);
call prescribe('Johnson', 'Dr.Marcus', 'Forgeta', 1);
call prescribe('Williams', 'Dr.Marcus', 'Happyza', 1);
call prescribe('Phillips', 'Dr.McCoy', 'Forgeta', 1);

-- These prescriptions should fail
-- Pregnancy violation
call prescribe('Jones', 'Dr.Marcus', 'Forgeta', 2);

-- Age restriction
call prescribe('BillyTheKid', 'Dr.Marcus', 'Muscula', 1);


-- Drug interaction
call prescribe('Williams', 'Dr.Marcus', 'Sadza', 1);



-- Testing trigger
-- Phillips (patient_id=4) becomes pregnant
-- Verify that a recommendation for pre-natal vitamins is added
-- and that her prescription for
update patient
set is_pregnant = True
where patient_id = 4;

select * from recommendation;
select * from prescription;


-- Phillips (patient_id=4) is no longer pregnant
-- Verify that the prenatal vitamin recommendation is gone
-- Her old prescription does not need to be added back

update patient
set is_pregnant = False
where patient_id = 4;

select * from recommendation;

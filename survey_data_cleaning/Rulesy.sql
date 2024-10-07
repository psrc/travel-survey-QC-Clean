--+------------------------------------------------------+--
/*  Load and clean raw hh survey data -- a.k.a. "Rulesy"  */
--+------------------------------------------------------+--

/* STEP 0. 	Settings and steps independent of data tables.  */

USE hhts_cleaning
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DECLARE @BingKey nvarchar = ['use your Bing API key here']

	--Create mode uber-categories for access/egress characterization, etc.
		DROP TABLE IF EXISTS 
			HHSurvey.transitmodes, HHSurvey.automodes, HHSurvey.walkmodes, HHSurvey.bikemodes, HHSurvey.airmodes,
			HHSurvey.work_purposes, HHSurvey.ed_purposes, HHSurvey.sleepstay_purposes, HHSurvey.social_purposes, 
			HHSurvey.brief_purposes, HHSurvey.PUDO_purposes, HHSurvey.under4hr_purposes, HHSurvey.NullFlags;

		CREATE TABLE HHSurvey.transitmodes 	(mode_id int PRIMARY KEY NOT NULL);
		CREATE TABLE HHSurvey.automodes 	(mode_id int PRIMARY KEY NOT NULL);
		CREATE TABLE HHSurvey.walkmodes 	(mode_id int PRIMARY KEY NOT NULL);
		CREATE TABLE HHSurvey.bikemodes 	(mode_id int PRIMARY KEY NOT NULL);
		CREATE TABLE HHSurvey.airmodes 	    (mode_id int PRIMARY KEY NOT NULL);

		CREATE TABLE HHSurvey.work_purposes      (purpose_id int PRIMARY KEY NOT NULL);
		CREATE TABLE HHSurvey.ed_purposes     	 (purpose_id int PRIMARY KEY NOT NULL);
		CREATE TABLE HHSurvey.sleepstay_purposes (purpose_id int PRIMARY KEY NOT NULL);
		CREATE TABLE HHSurvey.social_purposes 	 (purpose_id int PRIMARY KEY NOT NULL);
		CREATE TABLE HHSurvey.brief_purposes  	 (purpose_id int PRIMARY KEY NOT NULL);
		CREATE TABLE HHSurvey.PUDO_purposes   	 (purpose_id int PRIMARY KEY NOT NULL);
		CREATE TABLE HHSurvey.under4hr_purposes  (purpose_id int PRIMARY KEY NOT NULL);

		CREATE TABLE HHSurvey.NullFlags (flag_value int PRIMARY KEY NOT NULL); 
		GO

	-- Staff must verify/update the following code groupings:
		-- mode groupings
			INSERT INTO HHSurvey.transitmodes(mode_id) VALUES (23),(24),(26),(27),(28),(32),(41),(42),(52),(80);
			INSERT INTO HHSurvey.automodes(mode_id)    VALUES (3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(16),(17),(18),(21),(22),(33),(34),(36),(37),(47),(48),(54),(60),(70),(71),(77),(78),(79),(82);
			INSERT INTO HHSurvey.walkmodes(mode_id)    VALUES (1);
			INSERT INTO HHSurvey.bikemodes(mode_id)    VALUES (2),(65),(66),(67),(68),(69),(72),(73),(74),(75),(81);	
			INSERT INTO HHSurvey.airmodes(mode_id)     VALUES (31);

		-- purpose groupings		
			INSERT INTO HHSurvey.work_purposes(purpose_id)       VALUES (10),(11),(14);
			INSERT INTO HHSurvey.ed_purposes(purpose_id)         VALUES (3),(6),(21),(22),(23),(24),(25),(26);
			INSERT INTO HHSurvey.sleepstay_purposes(purpose_id)  VALUES (1),(34),(52),(55),(62),(97),(150),(152);
			INSERT INTO HHSurvey.social_purposes(purpose_id)     VALUES (7),(24),(52),(54),(62);
			INSERT INTO HHSurvey.brief_purposes(purpose_id)      VALUES (1),(9),(33),(51),(60),(61),(62),(97);
			INSERT INTO HHSurvey.PUDO_purposes(purpose_id)       VALUES (9),(45),(46),(47),(48);
			INSERT INTO HHSurvey.under4hr_purposes (purpose_id)  VALUES (32),(33),(50),(51),(53),(54),(56),(60),(61);

		--Null values
			INSERT INTO HHSurvey.NullFlags (flag_value) VALUES (-9999),(-9998),(-9997),(995),(-1);

	-- Verify/update hardcodes in HHSurvey.dest_purpose_updates: purpose 1 (home), 6 (general school), 45 (drop off), 46 (pick up), 54 (family activity), 60 (change mode), 97 (other); student 1 (not a student)
	-- Verify/update hardcodes in HHSurvey.generate_error_flags: purpose 1 (home), 30 (grocery shopping); mode 31 (air), mode 32 (ferry); student 1 (not a student)
	-- Verify/update correspondence table HHSurvey.Bing_location_types; see lower-level codes linked from https://learn.microsoft.com/en-us/bingmaps/rest-services/common-parameters-and-types/type-identifiers/

/* STEP 1. 	Load data and create geography fields and indexes  */
	--	Due to field import difficulties, the trip table is imported in two steps--a loosely typed table, then queried using CAST into a tightly typed table.
	-- 	Bulk insert isn't working right now because locations and permissions won't allow it.  For now, manually import household, persons tables via microsoft.import extension (wizard)

-- You must first alter line 340 to reference the current loosely-typed source table in SQL Server before running the following procedure.
	EXECUTE	HHSurvey.rulesy_setup_triptable;                    -- Migrates the survey data to properly structured tables; 
	EXECUTE	HHSurvey.rulesy_confirm_routine_locations;          -- Determine legitimate home, work, and school locations (household and person tables)

/* STEP 2.  Set up auto-logging and recalculate  */
	EXECUTE HHSurvey.audit_trigger;                             -- Creates the audit trail/logger
	ALTER TABLE HHSurvey.Trip ENABLE TRIGGER [tr_trip];         -- Enables the audit trail/logger; complement is 'ALTER TABLE HHSurvey.Trip DISABLE TRIGGER [tr_trip];'
	EXECUTE HHSurvey.tripnum_update;                            -- Tripnum must be sequential or later steps will fail.

/* STEP 3.  Rule-based individual field revisions */
	EXECUTE HHSurvey.update_membercounts;                       -- Revise travelers count to reflect passengers (lazy response?)	
	EXECUTE HHSurvey.initial_origin_purpose;                    -- Origin purpose assignment: Assumes purpose codes: 1 (home) and 10 (primary work)
	EXECUTE HHSurvey.dest_purpose_updates;                      -- Destination purpose revisions (extensive)

/* STEP 4. Revise travel times (and where necessary, mode) */  
	EXECUTE HHSurvey.revise_excessive_speed_trips @BingKey;     -- Change departure or arrival times for records that would qualify for 'excessive speed' flag

/* STEP 5.	Trip linking */
	EXECUTE HHSurvey.trip_link_prep;                            -- Sets up trip linking (only run once)
	EXECUTE HHSurvey.link_trips;                                -- Executes trip linking. Can be called from Fixie for edited trips

/* Step 6. Impute missing purpose for cases that can be assumed by location */
	EXECUTE HHSurvey.impute_purpose_from_location @BingKey;     -- Utilizes table HHSurvey.Bing_location_types, for verification see step 0 above
			 
/* STEP 7. Harmonize trips where possible: add trips for non-reporting cotravelers, missing trips between destinations, and remove duplicates  */
	--FYI HHSurvey.insert_silent_passenger_trips exists but intentionally is NOT used; RSG is also doing something on this issue.
	--FYI HHSurvey.fill_missing_link exists but intentionally is NOT used; we have accepted the missing links rather than impute so many trips.

	EXECUTE HHSurvey.fix_mistaken_passenger_carryovers;         -- When 'driver' code or work purpose are attributed to accompanying passengers
	EXECUTE HHSurvey.trip_removals;                             -- Creates removed_trip table & removes duplicated 'go home' trips created by rMove
	EXECUTE HHSurvey.cleanup_trips;	                            -- Snap origin points to prior destination, when proximate

/* STEP 8. Flag inconsistencies */
/*	as additional error patterns behind these flags are identified, rules to correct them can be added to Step 3 or elsewhere in Rulesy as makes sense.*/
	EXECUTE HHSurvey.setup_error_flags;
	EXECUTE HHSurvey.generate_error_flags;

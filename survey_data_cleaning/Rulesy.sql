-- -------------------------------------------------------
/* Load and clean raw hh survey data -- a.k.a. "Rulesy" */
-- -------------------------------------------------------

/* STEP 0. 	Settings and steps independent of data tables.  */

USE hhts_cleaning
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DECLARE @BingKey nvarchar = ['use your Bing API key here']

	--Create mode uber-categories for access/egress characterization, etc.
		DROP TABLE IF EXISTS HHSurvey.transitmodes, HHSurvey.automodes, HHSurvey.walkmodes, HHSurvey.bikemodes, 
			HHSurvey.WorkPurposes, HHSurvey.work_purposes, HHSurvey.ed_purposes,
			HHSurvey.trip_ingredients_done, HHSurvey.error_types, HHSurvey.NullFlags;
		CREATE TABLE HHSurvey.transitmodes 	  (mode_id int PRIMARY KEY NOT NULL);
		CREATE TABLE HHSurvey.automodes 	  (mode_id int PRIMARY KEY NOT NULL);
		CREATE TABLE HHSurvey.walkmodes 	  (mode_id int PRIMARY KEY NOT NULL);
		CREATE TABLE HHSurvey.bikemodes 	  (mode_id int PRIMARY KEY NOT NULL);
		CREATE TABLE HHSurvey.work_purposes   (purpose_id int PRIMARY KEY NOT NULL);
		CREATE TABLE HHSurvey.ed_purposes     (purpose_id int PRIMARY KEY NOT NULL);				
		CREATE TABLE HHSurvey.error_types	  (error_flag nvarchar(100) NULL, vital int NULL);
		CREATE TABLE HHSurvey.NullFlags       (flag_value int not null); 
		GO
	-- I haven't yet found a way to build the CLR regex pattern string from a variable expression, so if the sets in these tables change, the groupings in STEP 5 will likely need to be updated as well.
	-- mode groupings
		INSERT INTO HHSurvey.transitmodes(mode_id)     VALUES (23),(24),(26),(27),(28),(32),(41),(42),(52),(80);
		INSERT INTO HHSurvey.automodes(mode_id)        VALUES (3),(4),(5),(6),(7),(8),(9),(10),(11),(12),(16),(17),(18),(21),(22),(33),(34),(36),(37),(47),(48),(54),(60),(70),(71),(77),(78),(79),(82);
		INSERT INTO HHSurvey.walkmodes(mode_id)        VALUES (1);
		INSERT INTO HHSurvey.bikemodes(mode_id)        VALUES (2),(65),(66),(67),(68),(69),(72),(73),(74),(75),(81);	
		INSERT INTO HHSurvey.work_purposes(purpose_id) VALUES (1),(10),(11),(14)
		INSERT INTO HHSurvey.ed_purposes(purpose_id)   VALUES (3),(6),(21),(22),(23),(24),(25),(26)


		INSERT INTO HHSurvey.error_types (error_flag, vital) VALUES
			('unlicensed driver',0),
			('underage driver',0),
			('non-student + school trip',0),
			('non-worker + work trip',0),
			('no activity time after',0),			
			('no activity time before',0),
			('missing next trip link',0),
			('missing prior trip link',1),
			('same dest as next',0),
			('same dest as prior',1),
			('same transit line listed 2x+',0),
			('starts, not from home',0),
			('ends day, not home',0),
			('too long at dest',1),
			('excessive speed',1),
			('too slow',1),
			('purpose at odds w/ dest',1),
			('PUDO, no +/- travelers',0),
			('time overlap',1);	
		INSERT INTO HHSurvey.NullFlags (flag_value) VALUES (-9999),(-9998),(-9997),(995),(-1);

	-- Verify/update hardcoded dest_purpose codes in HHSurvey.dest_purpose_updates
	-- Verify/update hardcoded dest_purpose codes in HHSurvey.generate_error_flags
	-- Verify/update hardcoded mode groupings in HHSurvey.link_trips (combines groups above in regex expressions)
	-- Verify/update correspondence table HHSurvey.Bing_location_types; see lower-level codes linked from https://learn.microsoft.com/en-us/bingmaps/rest-services/common-parameters-and-types/type-identifiers/

/* STEP 1. 	Load data and create geography fields and indexes  */
	--	Due to field import difficulties, the trip table is imported in two steps--a loosely typed table, then queried using CAST into a tightly typed table.
	-- 	Bulk insert isn't working right now because locations and permissions won't allow it.  For now, manually import household, persons tables via microsoft.import extension (wizard)
	--  Must alter the following procedure (line 340) to reference the current loosely-typed source table in SQL Server.

	EXECUTE	HHSurvey.rulesy_setup_triptable;

	-- Determine legitimate home location:	
	EXECUTE	HHSurvey.rulesy_confirm_routine_locations;

/* STEP 2.  Set up auto-logging and recalculate  */
		
	-- Enable the audit trail/logger
	EXECUTE HHSurvey.rulesy_audit_trigger
	ALTER TABLE HHSurvey.Trip ENABLE TRIGGER [tr_trip];

	-- Tripnum must be sequential or later steps will fail.
	EXECUTE HHSurvey.tripnum_update;

/* STEP 3.  Rule-based individual field revisions */

	--A. Revise travelers count to reflect passengers (lazy response?)
		WITH membercounts (tripid, membercount)
		AS (
			select tripid, count(member) 
			from (		  SELECT tripid, hhmember1 AS member FROM HHSurvey.Trip 
				union all SELECT tripid, hhmember2 AS member FROM HHSurvey.Trip 
				union all SELECT tripid, hhmember3 AS member FROM HHSurvey.Trip 
				union all SELECT tripid, hhmember4 AS member FROM HHSurvey.Trip 
				union all SELECT tripid, hhmember5 AS member FROM HHSurvey.Trip 
				union all SELECT tripid, hhmember6 AS member FROM HHSurvey.Trip 
				union all SELECT tripid, hhmember7 AS member FROM HHSurvey.Trip 
				union all SELECT tripid, hhmember8 AS member FROM HHSurvey.Trip 
				union all SELECT tripid, hhmember9 AS member FROM HHSurvey.Trip
			) AS members
			where member not in (SELECT flag_value FROM HHSurvey.NullFlags)
			group by tripid
		)
		update t
		set t.travelers_hh = membercounts.membercount
		from membercounts
			join HHSurvey.Trip AS t ON t.tripid = membercounts.tripid
		where t.travelers_hh > membercounts.membercount 
			or t.travelers_hh is null
			or t.travelers_hh in (SELECT flag_value FROM HHSurvey.NullFlags);
		
		UPDATE t
			SET t.travelers_total = t.travelers_hh
			FROM HHSurvey.Trip AS t
			WHERE t.travelers_total < t.travelers_hh	
				or t.travelers_total in (SELECT flag_value FROM HHSurvey.NullFlags);
	
	--B. Origin purpose assignment	

		 -- to 'home' (should be largest share of cases)
		UPDATE t
		SET 	t.origin_purpose   = 1,
				t.origin_geog = h.home_geog,
				t.origin_lat  = h.home_lat,
				t.origin_lng  = h.home_lng,
				t.origin_label = 'HOME'
		FROM HHSurvey.Trip AS t JOIN HHSurvey.Household AS h ON t.hhid = h.hhid
			WHERE t.tripnum = 1 AND t.origin_purpose NOT IN(1,10)
				AND t.origin_geog.STDistance(h.home_geog) < 300;

		 -- to 'work'
		UPDATE t
		SET 	t.origin_purpose   = 10,
				t.origin_geog = p.work_geog,
				t.origin_lat  = p.work_lat,
				t.origin_lng  = p.work_lng,
				t.origin_label = 'WORK'
		FROM HHSurvey.Trip AS t JOIN HHSurvey.Person AS p ON t.person_id = p.person_id
			WHERE t.tripnum = 1 AND t.origin_purpose NOT IN(1,10)
				AND t.origin_geog.STDistance(p.work_geog) < 300;

	--C. Destination purpose		

		EXECUTE HHSurvey.dest_purpose_updates;

/* STEP 4. Revise travel times (and where necessary, mode) */  
	
	-- Change departure or arrival times for records that would qualify for 'excessive speed' flag

	-- Prep steps for trip linking
	EXECUTE HHSurvey.rulesy_trip_link_prep;

/* STEP 5.	Trip linking */
	EXECUTE HHSurvey.trip_link_prep;

	EXECUTE HHSurvey.link_trips;

/* Step 4b. Impute missing purpose for cases that can be assumed by location; relevant primarily for rMove */

	EXECUTE HHSurvey.impute_purpose_from_location @BingKey;
			 
/* STEP 7. Harmonize trips where possible: add trips for non-reporting cotravelers, missing trips between destinations, and remove duplicates  */

	--FYI HHSurvey.insert_silent_passenger_trips exists but intentionally is NOT used; RSG is also doing something on this issue.
	--FYI HHSurvey.fill_missing_link exists but intentionally is NOT used

	--recode driver flag when mistakenly applied to passengers and a hh driver is present
	UPDATE t
		SET t.driver = 2, t.revision_code = CONCAT(t.revision_code, '10,')
		FROM HHSurvey.Trip AS t JOIN HHSurvey.person AS p ON t.person_id = p.person_id
		WHERE t.driver = 1 AND (p.age < 4 OR p.license = 3)
			AND EXISTS (SELECT 1 FROM (VALUES (t.hhmember1),(t.hhmember2),(t.hhmember3),(t.hhmember4),(t.hhmember5),(t.hhmember6),(t.hhmember7),(t.hhmember8),(t.hhmember9)) AS hhmem(member) 
			            JOIN HHSurvey.person as p2 ON hhmem.member = p2.pernum WHERE p2.license in(1,2) AND p2.age > 3);

	--recode work purpose when mistakenly applied to passengers and a hh worker is present
	UPDATE t
		SET t.dest_purpose = 97, t.revision_code = CONCAT(t.revision_code, '11,')
		FROM HHSurvey.Trip AS t JOIN HHSurvey.person AS p ON t.person_id = p.person_id
		WHERE t.dest_purpose IN(10,11,14) AND (p.age < 4 OR p.employment = 0)
			AND EXISTS (SELECT 1 FROM (VALUES (t.hhmember1),(t.hhmember2),(t.hhmember3),(t.hhmember4),(t.hhmember5),(t.hhmember6),(t.hhmember7),(t.hhmember8),(t.hhmember9)) AS hhmem(member) 
			            JOIN HHSurvey.person as p2 ON hhmem.member = p2.pernum WHERE p2.employment = 1 AND p2.age > 3);

	--Remove duplicated home trips generated by the app
	DROP TABLE IF EXISTS HHSurvey.removed_trip;
	GO
	SELECT TOP 0 trip.* INTO HHSurvey.removed_trip
		FROM HHSurvey.Trip
	UNION ALL -- union for the side effect of preventing recid from being an IDENTITY column.
	SELECT top 0 Trip.* 
		FROM HHSurvey.Trip
	GO
	TRUNCATE TABLE HHSurvey.removed_trip;
	
	WITH cte AS 
	(SELECT t.recid 
		FROM HHSurvey.Trip AS t 
		JOIN 		HHSurvey.Trip AS prior_t ON t.person_id = prior_t.person_id AND t.tripnum - 1 = prior_t.tripnum AND t.daynum = prior_t.daynum
		LEFT JOIN 	HHSurvey.Trip AS next_t  ON t.person_id = next_t.person_id  AND t.tripnum + 1 = next_t.tripnum  AND t.daynum = next_t.daynum
		WHERE t.origin_purpose = 1 AND t.dest_purpose = 1 AND next_t.recid IS NULL AND ABS(t.dest_geog.STDistance(t.origin_geog)) < 100 ) -- points within 100m of one another
	DELETE FROM HHSurvey.Trip OUTPUT deleted.* INTO HHSurvey.removed_trip
		WHERE EXISTS (SELECT 1 FROM cte WHERE trip.recid = cte.recid);

	UPDATE t
	SET t.origin_geog=prev_t.dest_geog,
		t.origin_lat=prev_t.dest_geog.Lat,
		t.origin_lng=prev_t.dest_geog.Long
		FROM HHSurvey.Trip AS t JOIN HHSurvey.Trip AS prev_t ON t.person_id=prev_t.person_id AND t.tripnum -1 = prev_t.tripnum
		WHERE t.origin_geog.STEquals(prev_t.dest_geog)=0 AND t.origin_geog.STDistance(prev_t.dest_geog)<100;

	-- Update origin points to match the prior destination
	UPDATE t 
		SET t.origin_lat=prev_t.dest_lat,
			t.origin_lng=prev_t.dest_lng,
			t.origin_geog=prev_t.dest_geog
		FROM HHSurvey.Trip AS t JOIN HHSurvey.Trip AS prev_t ON t.person_id=prev_t.person_id AND t.tripnum -1 = prev_t.tripnum
		WHERE t.origin_lat <> prev_t.dest_lat OR t.origin_lng <> prev_t.dest_lng;

/* STEP 8. Flag inconsistencies */
/*	as additional error patterns behind these flags are identified, rules to address them can be added to Step 3 or elsewhere in Rulesy as makes sense.*/

	DROP TABLE IF EXISTS HHSurvey.hh_error_flags;
	CREATE TABLE HHSurvey.hh_error_flags (hhid decimal(19,0), error_flag NVARCHAR(100));
	GO
	INSERT INTO HHSurvey.hh_error_flags (hhid, error_flag)
	SELECT h.hhid, 'zero trips' FROM HHSurvey.household AS h LEFT JOIN HHSurvey.Trip AS t ON h.hhid = t.hhid
		WHERE t.hhid IS NULL
		GROUP BY h.hhid;

	DROP TABLE IF EXISTS HHSurvey.trip_error_flags;
	CREATE TABLE HHSurvey.trip_error_flags(
		recid decimal(19,0) not NULL,
		person_id decimal(19,0) not NULL,
		tripnum int not null,
		error_flag varchar(100)
		PRIMARY KEY (person_id, recid, error_flag)
		);
	GO
	EXECUTE HHSurvey.generate_error_flags;

/* Insert trips for those who were reported as a passenger by another traveler but did not report the trip themselves 
-- We haven't been using this because the conditions generate no trips
-- Relaxed conditions could generate a lot of trips; the general issue is being addressed by RSG
*/

-- Helper procedure
    DROP PROCEDURE IF EXISTS HHSurvey.pernum_silent_passenger_trips;
    GO

    CREATE PROCEDURE HHSurvey.pernum_silent_passenger_trips @respondent int=0  
    AS BEGIN
        WITH cte AS 
            (SELECT -- select fields necessary for new trip records	
                t.hhid, spt.passengerid AS person_id, CAST(RIGHT(spt.passengerid,2) AS int) AS pernum,
                t.depart_time_timestamp, t.arrival_time_timestamp,
                t.dest_label, t.dest_lat, t.dest_lng,
                t.distance_miles, t.travel_time,
                t.hhmember1, t.hhmember2, t.hhmember3, t.hhmember4, t.hhmember5, t.hhmember6, t.hhmember7, t.hhmember8, t.hhmember9, t.travelers_hh, t.travelers_nonhh, t.travelers_total,
                t.mode_acc, t.mode_egr, t.mode_1,
                t.origin_geog, t.origin_lat, t.origin_lng, t.dest_geog, t.dest_county, t.dest_city, t.dest_zip, t.dest_is_home, t.dest_is_work, 1 AS psrc_inserted, CONCAT(t.revision_code, '9,') AS revision_code
            FROM HHSurvey.silent_passenger_trip AS spt -- insert only when the CTE trip doesn't overlap any trip by the same person; doesn't matter if an intersecting trip reports the other hhmembers or not.
                JOIN HHSurvey.Trip as t ON spt.recid = t.recid
            WHERE spt.respondent = @respondent
            )
    INSERT INTO HHSurvey.Trip
            (hhid, person_id, pernum, 
            depart_time_timestamp, arrival_time_timestamp,
            dest_label, dest_lat, dest_lng,
            distance_miles, travel_time,
            hhmember1, hhmember2, hhmember3, hhmember4, hhmember5, hhmember6, hhmember7, hhmember8, hhmember9, travelers_hh, travelers_nonhh, travelers_total,
            mode_acc, mode_egr, mode_1,
            origin_geog, origin_lat, origin_lng, dest_geog, dest_county, dest_city, dest_zip, dest_is_home, dest_is_work, psrc_inserted, revision_code)
        SELECT * FROM cte 
        WHERE NOT EXISTS (SELECT 1 FROM HHSurvey.Trip AS t WHERE cte.person_id = t.person_id
                                AND ((cte.depart_time_timestamp BETWEEN t.depart_time_timestamp AND t.arrival_time_timestamp)
                                OR (cte.arrival_time_timestamp BETWEEN t.depart_time_timestamp AND t.arrival_time_timestamp)));	
    END
    GO

-- Primary procedure

    DROP PROCEDURE IF EXISTS HHSurvey.insert_silent_passenger_trips;
    GO

    CREATE PROCEDURE HHSurvey.insert_silent_passenger_trips
    AS BEGIN

        BEGIN TRANSACTION;   
        DROP TABLE IF EXISTS HHSurvey.silent_passenger_trip;
        COMMIT TRANSACTION;
        
        BEGIN TRANSACTION;
        WITH cte AS --create CTE set of passenger trips
                (         SELECT recid, pernum AS respondent, hhmember1  as passengerid FROM HHSurvey.Trip WHERE hhmember1  IS NOT NULL AND hhmember1  not in (SELECT flag_value FROM HHSurvey.NullFlags) AND hhmember1  <> pernum
                UNION ALL SELECT recid, pernum AS respondent, hhmember2  as passengerid FROM HHSurvey.Trip WHERE hhmember2  IS NOT NULL AND hhmember2  not in (SELECT flag_value FROM HHSurvey.NullFlags) AND hhmember2  <> pernum
                UNION ALL SELECT recid, pernum AS respondent, hhmember3  as passengerid FROM HHSurvey.Trip WHERE hhmember3  IS NOT NULL AND hhmember3  not in (SELECT flag_value FROM HHSurvey.NullFlags) AND hhmember3  <> pernum
                UNION ALL SELECT recid, pernum AS respondent, hhmember4  as passengerid FROM HHSurvey.Trip WHERE hhmember4  IS NOT NULL AND hhmember4  not in (SELECT flag_value FROM HHSurvey.NullFlags) AND hhmember4  <> pernum
                UNION ALL SELECT recid, pernum AS respondent, hhmember5  as passengerid FROM HHSurvey.Trip WHERE hhmember5  IS NOT NULL AND hhmember5  not in (SELECT flag_value FROM HHSurvey.NullFlags) AND hhmember5  <> pernum
                UNION ALL SELECT recid, pernum AS respondent, hhmember6  as passengerid FROM HHSurvey.Trip WHERE hhmember6  IS NOT NULL AND hhmember6  not in (SELECT flag_value FROM HHSurvey.NullFlags) AND hhmember6  <> pernum
                UNION ALL SELECT recid, pernum AS respondent, hhmember7  as passengerid FROM HHSurvey.Trip WHERE hhmember7  IS NOT NULL AND hhmember7  not in (SELECT flag_value FROM HHSurvey.NullFlags) AND hhmember7  <> pernum
                UNION ALL SELECT recid, pernum AS respondent, hhmember8  as passengerid FROM HHSurvey.Trip WHERE hhmember8  IS NOT NULL AND hhmember8  not in (SELECT flag_value FROM HHSurvey.NullFlags) AND hhmember8  <> pernum
                UNION ALL SELECT recid, pernum AS respondent, hhmember9  as passengerid FROM HHSurvey.Trip WHERE hhmember9  IS NOT NULL AND hhmember9  not in (SELECT flag_value FROM HHSurvey.NullFlags) AND hhmember9  <> pernum)
        SELECT recid, respondent, passengerid INTO HHSurvey.silent_passenger_trip FROM cte GROUP BY recid, respondent, passengerid;
        COMMIT TRANSACTION;

        /* 	Batching by respondent prevents duplication in the case silent passengers were reported by multiple household members on the same trip.
            While there were copied trips with silent passengers listed in both (as they should), the 2017 data had no silent passenger trips in which pernum 1 was not involved;
            that is not guaranteed, so I've left the 8 procedure calls in, although later ones can be expected not to have an effect
        */ 
        EXECUTE HHSurvey.pernum_silent_passenger_trips 1;
        EXECUTE HHSurvey.pernum_silent_passenger_trips 2;
        EXECUTE HHSurvey.pernum_silent_passenger_trips 3;
        EXECUTE HHSurvey.pernum_silent_passenger_trips 4;
        EXECUTE HHSurvey.pernum_silent_passenger_trips 5;
        EXECUTE HHSurvey.pernum_silent_passenger_trips 6;
        EXECUTE HHSurvey.pernum_silent_passenger_trips 7;
        EXECUTE HHSurvey.pernum_silent_passenger_trips 8;
        EXECUTE HHSurvey.pernum_silent_passenger_trips 9;
        DROP PROCEDURE HHSurvey.pernum_silent_passenger_trips;
        DROP TABLE HHSurvey.silent_passenger_trip;

        EXEC HHSurvey.recalculate_after_edit;

        EXECUTE HHSurvey.tripnum_update; --after adding records, we need to renumber them consecutively 
        EXECUTE HHSurvey.dest_purpose_updates;  --running these again to apply to linked trips, JIC
END

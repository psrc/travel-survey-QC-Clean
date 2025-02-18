/* Update derived tripnum and other derived fields linked to trip departure & arrival, origin & destination --incl. speed
--  Used in both Rulesy & Fixie */

-- Updates tripnum to be sequential in time
    DROP PROCEDURE IF EXISTS HHSurvey.tripnum_update;
    GO
    CREATE PROCEDURE HHSurvey.tripnum_update @target_person_id decimal = NULL --optional parameter
    AS BEGIN
    WITH tripnum_rev(recid, person_id, tripnum) AS
        (SELECT t0.recid, t0.person_id, ROW_NUMBER() OVER(PARTITION BY t0.person_id ORDER BY t0.depart_time_timestamp ASC, 
        t0.arrival_time_timestamp ASC) AS tripnum 
            FROM HHSurvey.Trip AS t0 
            WHERE t0.person_id = CASE WHEN @target_person_id IS NULL THEN t0.person_id ELSE @target_person_id END)
    UPDATE t
        SET t.tripnum = tripnum_rev.tripnum
        FROM HHSurvey.Trip AS t JOIN tripnum_rev ON t.recid=tripnum_rev.recid AND t.person_id = tripnum_rev.person_id
        WHERE t.tripnum <> tripnum_rev.tripnum OR t.tripnum IS NULL;
    END
    GO

-- Recalculation of derived fields; utilizes tripnum update above
    DROP PROCEDURE IF EXISTS HHSurvey.recalculate_after_edit;
    GO
    CREATE PROCEDURE HHSurvey.recalculate_after_edit
        @target_person_id decimal = NULL --optional to limit to the record just edited 
    AS BEGIN
        SET NOCOUNT ON

        EXECUTE HHSurvey.tripnum_update @target_person_id;

        WITH cte AS
        (SELECT t0.person_id, t0.depart_time_timestamp AS start_stamp
                FROM HHSurvey.Trip AS t0 
                WHERE t0.tripnum = 1 AND t0.depart_time_timestamp IS NOT NULL)
        UPDATE t SET
            t.daynum = 1 + DATEDIFF(day, cte.start_stamp, (CASE WHEN DATEPART(Hour, t.depart_time_timestamp) < 3 
                                                                THEN CAST(DATEADD(Hour, -3, t.depart_time_timestamp) AS DATE)
                                                                ELSE CAST(t.depart_time_timestamp AS DATE) END)),
            t.speed_mph			= CASE WHEN (t.distance_miles > 0 AND (CAST(DATEDIFF_BIG (second, t.depart_time_timestamp, t.arrival_time_timestamp) AS numeric)/3600) > 0) 
                                        THEN  t.distance_miles / (CAST(DATEDIFF_BIG (second, t.depart_time_timestamp, t.arrival_time_timestamp) AS numeric)/3600) 
                                        ELSE 0 END,
            t.travel_time 	= CAST(DATEDIFF(second, t.depart_time_timestamp, t.arrival_time_timestamp) AS numeric)/60,  -- for edited records, this should be the accepted travel duration
            t.traveldate        = CAST(DATEADD(hour, -3, t.depart_time_timestamp) AS date),			   	
            t.dest_geog = geography::STGeomFromText('POINT(' + CAST(t.dest_lng AS VARCHAR(20)) + ' ' + CAST(t.dest_lat AS VARCHAR(20)) + ')', 4326), 
            t.origin_geog  = geography::STGeomFromText('POINT(' + CAST(t.origin_lng AS VARCHAR(20)) + ' ' + CAST(t.origin_lat AS VARCHAR(20)) + ')', 4326) 
        FROM HHSurvey.Trip AS t JOIN cte ON t.person_id = cte.person_id
        WHERE t.person_id = (CASE WHEN @target_person_id IS NULL THEN t.person_id ELSE @target_person_id END);

        UPDATE next_t SET
            next_t.origin_purpose = t.dest_purpose
            FROM HHSurvey.Trip AS t JOIN HHSurvey.Trip AS next_t ON t.person_id = next_t.person_id AND t.tripnum + 1 = next_t.tripnum
            WHERE t.person_id = (CASE WHEN @target_person_id IS NULL THEN t.person_id ELSE @target_person_id END);

    END
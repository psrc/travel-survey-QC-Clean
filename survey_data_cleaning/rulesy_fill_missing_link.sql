/* Add trips in cases the origin of a trip is over 500m from the destination of the prior, with conditions */
-- Not currently used
/*
DROP PROCEDURE IF EXISTS HHSurvey.fill_missing_link;
GO
CREATE PROCEDURE HHSurvey.fill_missing_link
AS BEGIN

    BEGIN TRANSACTION;
	EXECUTE HHSurvey.tripnum_update;
	COMMIT TRANSACTION;

    BEGIN TRANSACTION;
	WITH cte_ref AS (
		SELECT t.recid,
					Elmer.dbo.route_mi_min(t.origin_lng, t.origin_lat, t.dest_lng, t.dest_lat, 
										   CASE WHEN EXISTS (SELECT 1 FROM HHSurvey.AutoModes    AS am WHERE am.mode_id = t.mode_1) THEN 'driving' 
										   		--WHEN EXISTS (SELECT 1 FROM HHSurvey.TransitModes AS tm WHERE tm.mode_id = t.mode_1) THEN 'transit'
												WHEN t.mode_1=1 THEN 'walking' ELSE 'driving' END,   
												@BingKey) AS mi_min_result,
					CASE WHEN t.mode_1 = nxt.mode_1 AND EXISTS (SELECT 1 FROM HHSurvey.AutoModes AS am WHERE am.mode_id = t.mode_1) THEN t.mode_1 ELSE 995 END AS mode,
					CASE WHEN DATEDIFF(Day, t.arrival_time_timestamp, nxt.depart_time_timestamp) = 0 THEN '16,' ELSE '17,' END AS revision_code,
					CASE WHEN DATEDIFF(Day, t.arrival_time_timestamp, nxt.depart_time_timestamp) = 0 THEN t.arrival_time_timestamp
							WHEN (t.dest_geog.STDistance(h.home_geog) < 300 OR t.dest_purpose IN(1,52,55,58,97)) THEN  DATETIME2FROMPARTS(DATEPART(year,nxt.depart_time_timestamp),DATEPART(month,nxt.depart_time_timestamp),DATEPART(day,nxt.depart_time_timestamp),3,0,0,0,0)
							ELSE t.arrival_time_timestamp END AS travelwindow_start,
					CASE WHEN DATEDIFF(Day, t.arrival_time_timestamp, nxt.depart_time_timestamp) = 0 THEN nxt.depart_time_timestamp
							WHEN (t.dest_geog.STDistance(h.home_geog) > 300 AND t.dest_purpose NOT IN(1,52,55,58,97)) THEN  DATETIME2FROMPARTS(DATEPART(year,nxt.depart_time_timestamp),DATEPART(month,nxt.depart_time_timestamp),DATEPART(day,nxt.depart_time_timestamp),0,0,0,0,0)
							ELSE nxt.depart_time_timestamp END AS travelwindow_end,
					CASE WHEN t.travelers_hh = nxt.travelers_hh THEN t.travelers_hh ELSE -9997 END AS travelers_hh, 
					CASE WHEN t.travelers_nonhh = nxt.travelers_nonhh THEN t.travelers_nonhh ELSE -9997 END AS travelers_nonhh,
					CASE WHEN t.travelers_total = nxt.travelers_total THEN t.travelers_total ELSE -9997 END AS travelers_total					 
			INTO HHSurvey.cte_ref
			FROM HHSurvey.Trip AS t 
			JOIN HHSurvey.Trip AS nxt ON nxt.person_id = t.person_id AND nxt.tripnum = t.tripnum + 1
			JOIN HHSurvey.Household AS h ON t.hhid = h.hhid
			WHERE ABS(t.dest_geog.STDistance(nxt.origin_geog)) > 500),
	aml AS (SELECT recid, 
				   CAST(LEFT(mi_min_result, CHARINDEX(',',mi_min_result,)-1) AS float) AS distance, 
				   ROUND(CAST(RIGHT(mi_min_result,LEN(mi_min_result)-CHARINDEX(',',mi_min_result,)) AS float),0) AS mode1_minutes
			FROM HHSurvey.cte_ref
			WHERE CHARINDEX(mi_min_result,',')>1),		
	cte AS (SELECT cte_ref.recid, cte_ref.travelers_hh, cte_ref.travelers_nonhh, cte_ref.travelers_total, cte_ref.revision_code,
			DATEADD(Minute, ((DATEDIFF(Second, cte_ref.travelwindow_start, cte_ref.travelwindow_end) / 60 - aml.mode1_minutes) / 2), cte_ref.travelwindow_start) AS depart_time_timestamp,
			aml.mode1_minutes AS travel_minutes, aml.distance
			FROM HHSurvey.cte_ref JOIN aml ON cte_ref.recid = aml.recid
			WHERE (DATEDIFF(Second, cte_ref.travelwindow_start, cte_ref.travelwindow_end) / 60) > aml.mode1_minutes
			AND aml.distance > 0.3)
	INSERT INTO HHSurvey.Trip (hhid, person_id, pernum,  tripnum, psrc_inserted, revision_code, dest_purpose,
							mode_1, modes, travelers_hh, travelers_nonhh, travelers_total,
							origin_lat, origin_lng, origin_geog, dest_lat, dest_lng, dest_geog, 
							distance_miles, depart_time_timestamp, arrival_time_timestamp, travel_time)  --the last item was travel_time when combining rSurvey & rMove.
	SELECT t.hhid, t.person_id, t.pernum, 99 AS tripnum, 1 AS psrc_inserted, cte.revision_code, -9998 AS dest_purpose,
			t.mode_1, CAST(t.mode_1 AS NVARCHAR) AS modes, cte.travelers_hh, cte.travelers_nonhh, cte.travelers_total,
			t.dest_lat AS origin_lat, t.dest_lng AS origin_lng, t.dest_geog AS origin_geog, nxt.origin_lat AS dest_lat, nxt.origin_lng AS dest_lng, nxt.origin_geog AS dest_geog,
			cte.distance AS distance_miles, cte.depart_time_timestamp, DATEADD(Minute, cte.travel_minutes, cte.depart_time_timestamp) AS arrival_time_timestamp, cte.travel_minutes
		FROM HHSurvey.Trip AS t JOIN HHSurvey.Trip AS nxt ON nxt.person_id = t.person_id AND nxt.tripnum = t.tripnum + 1 JOIN cte ON t.recid = cte.recid;
	COMMIT TRANSACTION;

    BEGIN TRANSACTION;
	EXECUTE HHSurvey.recalculate_after_edit;
	COMMIT TRANSACTION;
END
*/

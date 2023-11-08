/* Defines the Views necessary to operate FixieUI  */

USE hhts_cleaning
GO

	DROP VIEW IF EXISTS HHSurvey.data2fixie;  --The primary subform view in FixieUI
	GO
	CREATE VIEW HHSurvey.data2fixie WITH SCHEMABINDING  
	AS
	SELECT t1.recid, t1.person_id, t1.hhid, t1.pernum, CASE WHEN h.hhgroup=11 THEN 'rMove' ELSE 'rSurvey' END AS hhgroup, 
	       CASE WHEN EXISTS (SELECT 1 FROM HHSurvey.Trip WHERE Trip.psrc_comment IS NOT NULL AND t1.person_id = Trip.person_id) THEN 1 ELSE 0 END AS Elevated, 0 AS Seattle,
			t1.tripnum, 
			STUFF(	COALESCE(',' + CAST(ma.mode_desc AS nvarchar), '') + 
				/*	COALESCE(',' + CAST(m1.mode_desc AS nvarchar), '') + 
					COALESCE(',' + CAST(m2.mode_desc AS nvarchar), '') + 
					COALESCE(',' + CAST(m3.mode_desc AS nvarchar), '') + 
					COALESCE(',' + CAST(m4.mode_desc AS nvarchar), '') +
				*/	COALESCE(',' + CAST(me.mode_desc AS nvarchar), ''), 1, 1, '') AS modes_desc,
			t1.daynum,	 
			FORMAT(t1.depart_time_timestamp,N'hh\:mm tt','en-US') AS depart_dhm,
			FORMAT(t1.arrival_time_timestamp,N'hh\:mm tt','en-US') AS arrive_dhm,
			ROUND(t1.distance_miles,1) AS miles,
			ROUND(t1.speed_mph,1) AS mph, 
			ROUND(t1.dest_geog.STDistance(t1.origin_geog) / 1609.344, 1) AS linear_miles,
			CASE WHEN DATEDIFF(minute, t1.depart_time_timestamp, t1.arrival_time_timestamp) > 0 
					THEN ROUND((t1.dest_geog.STDistance(t1.origin_geog) / 1609.344) / (CAST(DATEDIFF(second, t1.depart_time_timestamp, t1.arrival_time_timestamp) AS decimal) / 3600),1) 
					ELSE -9999 END AS linear_mph,
			STUFF(
					(SELECT ',' + tef.error_flag
						FROM HHSurvey.trip_error_flags AS tef
						WHERE tef.recid = t1.recid
						ORDER BY tef.error_flag DESC
						FOR XML PATH('')), 1, 1, NULL) AS Error,
			CASE WHEN t1.travelers_total = 1 THEN '' ELSE CONCAT(CAST(t1.travelers_total - 1 AS nvarchar),' - ', 
					STUFF(	
						COALESCE(',' + CASE WHEN t1.hhmember1 <> t1.pernum AND NOT EXISTS (SELECT flag_value from HHSurvey.NullFlags WHERE flag_value = t1.hhmember1) THEN RIGHT(CAST(t1.hhmember1 AS nvarchar),2) ELSE NULL END, '') +
						COALESCE(',' + CASE WHEN t1.hhmember2 <> t1.pernum AND NOT EXISTS (SELECT flag_value from HHSurvey.NullFlags WHERE flag_value = t1.hhmember2) THEN RIGHT(CAST(t1.hhmember2 AS nvarchar),2) ELSE NULL END, '') + 
						COALESCE(',' + CASE WHEN t1.hhmember3 <> t1.pernum AND NOT EXISTS (SELECT flag_value from HHSurvey.NullFlags WHERE flag_value = t1.hhmember3) THEN RIGHT(CAST(t1.hhmember3 AS nvarchar),2) ELSE NULL END, '') + 
						COALESCE(',' + CASE WHEN t1.hhmember4 <> t1.pernum AND NOT EXISTS (SELECT flag_value from HHSurvey.NullFlags WHERE flag_value = t1.hhmember4) THEN RIGHT(CAST(t1.hhmember4 AS nvarchar),2) ELSE NULL END, '') + 
						COALESCE(',' + CASE WHEN t1.hhmember5 <> t1.pernum AND NOT EXISTS (SELECT flag_value from HHSurvey.NullFlags WHERE flag_value = t1.hhmember5) THEN RIGHT(CAST(t1.hhmember5 AS nvarchar),2) ELSE NULL END, '') + 
						COALESCE(',' + CASE WHEN t1.hhmember6 <> t1.pernum AND NOT EXISTS (SELECT flag_value from HHSurvey.NullFlags WHERE flag_value = t1.hhmember6) THEN RIGHT(CAST(t1.hhmember6 AS nvarchar),2) ELSE NULL END, '') + 
						COALESCE(',' + CASE WHEN t1.hhmember7 <> t1.pernum AND NOT EXISTS (SELECT flag_value from HHSurvey.NullFlags WHERE flag_value = t1.hhmember7) THEN RIGHT(CAST(t1.hhmember7 AS nvarchar),2) ELSE NULL END, '') + 
						COALESCE(',' + CASE WHEN t1.hhmember8 <> t1.pernum AND NOT EXISTS (SELECT flag_value from HHSurvey.NullFlags WHERE flag_value = t1.hhmember8) THEN RIGHT(CAST(t1.hhmember8 AS nvarchar),2) ELSE NULL END, '') + 
						COALESCE(',' + CASE WHEN t1.hhmember9 <> t1.pernum AND NOT EXISTS (SELECT flag_value from HHSurvey.NullFlags WHERE flag_value = t1.hhmember9) THEN RIGHT(CAST(t1.hhmember9 AS nvarchar),2) ELSE NULL END, ''), 
							1, 1, '')) END AS cotravelers,
				CONCAT(t1.origin_purpose, '-',tpo.purpose) AS origin_purpose, t1.dest_label, CONCAT(t1.dest_purpose, '-',tpd.purpose) AS dest_purpose, 
				CONCAT(CONVERT(varchar(30), (DATEDIFF(mi, t1.arrival_time_timestamp, t2.depart_time_timestamp) / 60)),'h',RIGHT('00'+CONVERT(varchar(30), (DATEDIFF(mi, t1.arrival_time_timestamp, CASE WHEN t2.recid IS NULL 
										THEN DATETIME2FROMPARTS(DATEPART(year,t1.arrival_time_timestamp),DATEPART(month,t1.arrival_time_timestamp),DATEPART(day,t1.arrival_time_timestamp),3,0,0,0,0) 
										ELSE t2.depart_time_timestamp END) % 60)),2),'m') AS duration_at_dest,
				CONCAT(CAST(t1.origin_lat AS VARCHAR(20)),', ',CAST(t1.origin_lng AS VARCHAR(20))) AS origin_coord,						 
				CONCAT(CAST(t1.dest_lat AS VARCHAR(20)),', ',CAST(t1.dest_lng AS VARCHAR(20))) AS dest_coord,
				t1.revision_code AS rc, t1.psrc_comment AS elevate_issue
		FROM HHSurvey.trip AS t1 LEFT JOIN HHSurvey.trip as t2 ON t1.person_id = t2.person_id AND (t1.tripnum+1) = t2.tripnum JOIN HHSurvey.Household AS h on h.hhid=t1.hhid
			LEFT JOIN HHSurvey.trip_mode AS ma ON t1.mode_acc=ma.mode_id
			LEFT JOIN HHSurvey.trip_mode AS m1 ON t1.mode_1=m1.mode_id
		/*	LEFT JOIN HHSurvey.trip_mode AS m2 ON t1.mode_2=m2.mode_id
			LEFT JOIN HHSurvey.trip_mode AS m3 ON t1.mode_3=m3.mode_id
			LEFT JOIN HHSurvey.trip_mode AS m4 ON t1.mode_4=m4.mode_id
		*/	LEFT JOIN HHSurvey.trip_mode AS me ON t1.mode_egr=me.mode_id
			LEFT JOIN HHSurvey.trip_purpose AS tpo ON t1.origin_purpose=tpo.purpose_id
			LEFT JOIN HHSurvey.trip_purpose AS tpd ON t1.dest_purpose=tpd.purpose_id;
	GO

	DROP VIEW IF EXISTS HHSurvey.pass2trip;  --View used to edit the trip table (since direct connection isn't possible)
	GO
	CREATE VIEW HHSurvey.pass2trip WITH SCHEMABINDING
	AS
	SELECT t.[recid]
		   ,h.[hhid]
		   ,t.[person_id]
		   ,t.[pernum]
		   ,t.[tripid]
		   ,t.[tripnum]
		   ,t.[traveldate]
		   ,t.[daynum]
		   ,CASE WHEN h.hhgroup=11 THEN 'rMove' ELSE 'rSurvey' END AS hhgroup
		   ,t.[copied_trip]
		   ,t.[svy_complete]
		   ,t.[depart_time_timestamp]
		   ,t.[arrival_time_timestamp]
		   ,t.[origin_label] AS origin_name
		   ,t.[origin_lat]
		   ,t.[origin_lng]
		   ,t.[dest_label] AS dest_name
		   ,t.[dest_lat]
		   ,t.[dest_lng]
		   ,t.distance_miles AS trip_path_distance
		   ,t.[travel_time]
		   ,t.[hhmember1]
		   ,t.[hhmember2]
		   ,t.[hhmember3]
		   ,t.[hhmember4]
		   ,t.[hhmember5]
		   ,t.[hhmember6]
		   ,t.[hhmember7]
		   ,t.[hhmember8]
		   ,t.[hhmember9]
		   ,t.[travelers_hh]
		   ,t.[travelers_nonhh]
		   ,t.[travelers_total]
		   ,t.[origin_purpose]
		   ,t.[dest_purpose]
		   ,t.[mode_1]
		   ,t.[mode_2]
		   ,t.[mode_3]
		   ,t.[mode_4]
		   ,t.[driver]
		   ,t.[change_vehicles]
		   ,t.[mode_acc]
		   ,t.[mode_egr]
		   ,t.[speed_mph]
		   ,t.[psrc_comment]
		   ,t.[psrc_resolved]
	FROM HHSurvey.Trip AS t JOIN HHSurvey.Household AS h on h.hhid=t.hhid;
	GO
	CREATE UNIQUE CLUSTERED INDEX PK_pass2trip ON HHSurvey.pass2trip(recid);

-- All-inclusive person-level views for FixieUI (only for reference)

		DROP VIEW IF EXISTS HHSurvey.person_all;
		GO
		CREATE VIEW HHSurvey.person_all WITH SCHEMABINDING AS
		SELECT p.person_id, p.hhid AS hhid, p.pernum, ac.agedesc AS Age, 
			CASE WHEN p.employment  = 0 THEN 'No' ELSE 'Yes' END AS Works, 
			CASE WHEN p.student = 1 THEN 'No' WHEN student = 2 THEN 'PT' WHEN p.student = 3 THEN 'FT' ELSE 'No' END AS Studies, 
			CASE WHEN h.hhgroup=11 THEN 'rMove' ELSE 'rSurvey' END AS HHGroup
		FROM HHSurvey.person AS p INNER JOIN HHSurvey.AgeCategories AS ac ON p.age = ac.agecode JOIN HHSurvey.Household AS h on h.hhid=p.hhid
		WHERE EXISTS (SELECT 1 FROM HHSurvey.Trip AS t WHERE p.person_id = t.person_id);
GO

-- Person-level views for FixieUI Main forms, separated by staff so as to avoid editing conflicts
		--DROP VIEW IF EXISTS HHSurvey.person_Abdi
		DROP VIEW IF EXISTS HHSurvey.Person_Grant
		--DROP VIEW IF EXISTS HHSurvey.Person_Mary
		DROP VIEW IF EXISTS HHSurvey.person_Parastoo
		--DROP VIEW IF EXISTS HHSurvey.person_Polina
		DROP VIEW IF EXISTS HHSurvey.person_Elevated
		DROP VIEW IF EXISTS HHSurvey.Person_Mike
		GO

	

		--alternate view for Mike
		CREATE VIEW HHSurvey.person_Mike WITH SCHEMABINDING AS
		SELECT p.person_id, p.hhid AS hhid, p.pernum, ac.agedesc AS Age, 
			CASE WHEN p.employment  = 0 THEN 'No' ELSE 'Yes' END AS Works, 
			CASE WHEN p.student = 1 THEN 'No' WHEN student = 2 THEN 'PT' WHEN p.student = 3 THEN 'FT' ELSE 'No' END AS Studies, 
			CASE WHEN h.hhgroup = 11 THEN 'rMove' WHEN h.hhgroup IS NOT NULL THEN 'rSurvey' ELSE 'n/a' END AS HHGroup
		FROM HHSurvey.person AS p INNER JOIN HHSurvey.AgeCategories AS ac ON p.age = ac.agecode JOIN HHSurvey.Household AS h on h.hhid=p.hhid 
		WHERE EXISTS (SELECT 1 FROM HHSurvey.trip_error_flags AS tef WHERE p.person_id = tef.person_id AND tef.error_flag='time overlap') OR
		EXISTS (SELECT 1 FROM HHSurvey.Trip AS tm WHERE p.person_id = tm.person_id AND (tm.psrc_comment LIKE 'ADD%' OR tm.psrc_comment LIKE 'insert%'));
		GO

		--alternate view for elevated records
		CREATE VIEW HHSurvey.person_Elevated WITH SCHEMABINDING AS
		SELECT p.person_id, p.hhid AS hhid, p.pernum, ac.agedesc AS Age, 
			CASE WHEN p.employment  = 0 THEN 'No' ELSE 'Yes' END AS Works, 
			CASE WHEN p.student = 1 THEN 'No' WHEN student = 2 THEN 'PT' WHEN p.student = 3 THEN 'FT' ELSE 'No' END AS Studies, 
			CASE WHEN h.hhgroup = 11 THEN 'rMove' WHEN h.hhgroup IS NOT NULL THEN 'rSurvey' ELSE 'n/a' END AS HHGroup
		FROM HHSurvey.person AS p INNER JOIN HHSurvey.AgeCategories AS ac ON p.age = ac.agecode JOIN HHSurvey.Household AS h on h.hhid=p.hhid
		WHERE EXISTS (SELECT 1 FROM HHSurvey.trip_error_flags AS tefx WHERE p.person_id = tefx.person_id) AND 
		      EXISTS (SELECT 1 FROM HHSurvey.Trip AS te WHERE p.person_id = te.person_id AND te.psrc_comment IS NOT NULL)
			  --AND NOT EXISTS (SELECT 1 FROM HHSurvey.person_Mike AS p1 WHERE p1.person_id = p.person_id)
			  ;
		GO 

		/*CREATE VIEW HHSurvey.person_Polina WITH SCHEMABINDING AS
		WITH cte AS (SELECT person_id FROM HHSurvey.person_Mike 
		   UNION ALL SELECT person_id FROM HHSurvey.person_Elevated) 
		SELECT p.person_id, p.hhid AS hhid, p.pernum, ac.agedesc AS Age, 
			CASE WHEN p.worker  = 0 THEN 'No' ELSE 'Yes' END AS Works, 
			CASE WHEN p.student = 1 THEN 'No' WHEN student = 2 THEN 'PT' WHEN p.student = 3 THEN 'FT' ELSE 'No' END AS Studies, 
			CASE WHEN p.hhgroup = 1 THEN 'rMove' WHEN p.hhgroup = 2 THEN 'rSurvey' ELSE 'n/a' END AS HHGroup
		FROM HHSurvey.person AS p INNER JOIN HHSurvey.AgeCategories AS ac ON p.age = ac.agecode
		WHERE Exists (SELECT 1 FROM HHSurvey.trip_error_flags AS tef WHERE p.person_id = tef.person_id AND tef.error_flag IN('PUDO, no +/- travelers','excessive speed','too long at dest?'))
		AND NOT EXISTS (SELECT 1 FROM cte WHERE cte.person_id=p.person_id)
		AND p.person_id < 2126436101;
		GO*/

		CREATE VIEW HHSurvey.person_Parastoo WITH SCHEMABINDING AS
		WITH cte AS (--SELECT person_id FROM HHSurvey.person_Mike UNION ALL 
		   SELECT person_id FROM HHSurvey.person_Elevated 
		   --UNION ALL SELECT person_id FROM HHSurvey.person_Polina
		   )
		SELECT p.person_id, p.hhid AS hhid, p.pernum, ac.agedesc AS Age, 
			CASE WHEN p.employment  = 0 THEN 'No' ELSE 'Yes' END AS Works, 
			CASE WHEN p.student = 1 THEN 'No' WHEN student = 2 THEN 'PT' WHEN p.student = 3 THEN 'FT' ELSE 'No' END AS Studies, 
			CASE WHEN h.hhgroup = 11 THEN 'rMove' WHEN h.hhgroup IS NOT NULL THEN 'rSurvey' ELSE 'n/a' END AS HHGroup
		FROM HHSurvey.person AS p INNER JOIN HHSurvey.AgeCategories AS ac ON p.age = ac.agecode JOIN HHSurvey.Household AS h on h.hhid=p.hhid
		WHERE Exists (SELECT 1 FROM HHSurvey.trip_error_flags AS tef WHERE p.person_id = tef.person_id)-- AND tef.error_flag IN('PUDO, no +/- travelers','excessive speed','too long at dest?'))
			AND NOT EXISTS (SELECT 1 FROM cte WHERE cte.person_id=p.person_id);
		GO 

		/*CREATE VIEW HHSurvey.person_Mary WITH SCHEMABINDING AS
		WITH cte AS (SELECT person_id FROM HHSurvey.person_Mike 
		   UNION ALL SELECT person_id FROM HHSurvey.person_Elevated 
		   UNION ALL SELECT person_id FROM HHSurvey.person_Parastoo
		   UNION ALL SELECT person_id FROM HHSurvey.person_Polina)
		SELECT p.person_id, p.hhid AS hhid, p.pernum, ac.agedesc AS Age, 
			CASE WHEN p.worker  = 0 THEN 'No' ELSE 'Yes' END AS Works, 
			CASE WHEN p.student = 1 THEN 'No' WHEN student = 2 THEN 'PT' WHEN p.student = 3 THEN 'FT' ELSE 'No' END AS Studies, 
			CASE WHEN p.hhgroup = 1 THEN 'rMove' WHEN p.hhgroup = 2 THEN 'rSurvey' ELSE 'n/a' END AS HHGroup
		FROM HHSurvey.person AS p INNER JOIN HHSurvey.AgeCategories AS ac ON p.age = ac.agecode
		WHERE Exists (SELECT 1 FROM HHSurvey.trip_error_flags AS tef WHERE tef.person_id = p.person_id)-- AND tef.error_flag IN('lone trip'))
			AND NOT EXISTS (SELECT 1 FROM cte WHERE cte.person_id=p.person_id);
		GO*/

		CREATE VIEW HHSurvey.person_Grant WITH SCHEMABINDING AS
		WITH cte AS (SELECT person_id FROM HHSurvey.person_Mike 
		   UNION ALL SELECT person_id FROM HHSurvey.person_Elevated 
		   UNION ALL SELECT person_id FROM HHSurvey.person_Parastoo
		   --UNION ALL SELECT person_id FROM HHSurvey.person_Polina
		   --UNION ALL SELECT person_id FROM HHSurvey.person_Mary
		   )
		SELECT p.person_id, p.hhid AS hhid, p.pernum, ac.agedesc AS Age, 
			CASE WHEN p.employment  = 0 THEN 'No' ELSE 'Yes' END AS Works, 
			CASE WHEN p.student = 1 THEN 'No' WHEN student = 2 THEN 'PT' WHEN p.student = 3 THEN 'FT' ELSE 'No' END AS Studies, 
			CASE WHEN h.hhgroup = 11 THEN 'rMove' WHEN h.hhgroup IS NOT NULL THEN 'rSurvey' ELSE 'n/a' END AS HHGroup
		FROM HHSurvey.person AS p INNER JOIN HHSurvey.AgeCategories AS ac ON p.age = ac.agecode JOIN HHSurvey.Household AS h on h.hhid=p.hhid
		WHERE Exists (SELECT 1 FROM HHSurvey.trip_error_flags AS tef WHERE tef.person_id = p.person_id)
		AND NOT EXISTS (SELECT 1 FROM cte WHERE cte.person_id = p.person_id);
		GO

		/*CREATE VIEW HHSurvey.person_Abdi WITH SCHEMABINDING AS
		WITH cte AS (SELECT person_id FROM HHSurvey.person_Mike 
		   UNION ALL SELECT person_id FROM HHSurvey.person_Elevated 
		   UNION ALL SELECT person_id FROM HHSurvey.person_Parastoo
		   UNION ALL SELECT person_id FROM HHSurvey.person_Polina
		   UNION ALL SELECT person_id FROM HHSurvey.person_Mary
		   UNION ALL SELECT person_id FROM HHSurvey.person_Grant)
		SELECT p.person_id, p.hhid AS hhid, p.pernum, ac.agedesc AS Age, 
			CASE WHEN p.worker  = 0 THEN 'No' ELSE 'Yes' END AS Works, 
			CASE WHEN p.student = 1 THEN 'No' WHEN student = 2 THEN 'PT' WHEN p.student = 3 THEN 'FT' ELSE 'No' END AS Studies, 
			CASE WHEN p.hhgroup = 1 THEN 'rMove' WHEN p.hhgroup = 2 THEN 'rSurvey' ELSE 'n/a' END AS HHGroup
		FROM HHSurvey.person AS p INNER JOIN HHSurvey.AgeCategories AS ac ON p.age = ac.agecode
		WHERE Exists (SELECT 1 FROM HHSurvey.trip_error_flags AS tef WHERE p.person_id = tef.person_id)
		AND NOT EXISTS (SELECT 1 FROM cte WHERE cte.person_id = p.person_id);
		GO*/

SELECT count(*),'Abdi' FROM HHSurvey.person_Abdi
UNION ALL select count(*),'Mary' FROM HHSurvey.person_Mary
UNION ALL select count(*),'Grant' FROM HHSurvey.person_Grant
--UNION ALL select count(*),'Polina' FROM HHSurvey.person_Polina
UNION ALL select count(*),'Parastoo' FROM HHSurvey.person_Parastoo
UNION ALL select count(*),'Mike' FROM HHSurvey.person_Mike
UNION ALL select count(*),'Elevated' FROM HHSurvey.person_Elevated

SELECT person_id FROM HHSurvey.person_Mike;
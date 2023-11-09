/* Procedures triggered or executed via pass-through queries in FixieUI  */

USE hhts_cleaning
GO

	-- DELETIONS:

			DROP PROCEDURE IF EXISTS HHSurvey.remove_trip;
			GO
			CREATE PROCEDURE HHSurvey.remove_trip 
				@target_recid int  NULL --Parameter necessary to have passed
			AS BEGIN
			DELETE FROM HHSurvey.trip OUTPUT deleted.* INTO HHSurvey.removed_trip
				WHERE trip.recid = @target_recid;
			END
			GO

	-- TRIP LINKING for specified sets during manual cleaning

			DROP PROCEDURE IF EXISTS HHSurvey.link_trip_via_id;
			GO
			USE hhts_cleaning;
			GO
			CREATE PROCEDURE HHSurvey.link_trip_via_id
				@recid_list nvarchar(255) NULL --Parameter necessary to have passed: comma-separated recids to be linked (not limited to two)
			AS BEGIN
			SET NOCOUNT ON; 
			SELECT CAST(Elmer.dbo.TRIM(value) AS int) AS recid INTO #recid_list 
				FROM STRING_SPLIT(@recid_list, ',')
				WHERE RTRIM(value) <> '';
			
			WITH cte AS (SELECT TOP 1 tripnum AS trip_link FROM HHSurvey.trip AS t JOIN #recid_list AS rid ON rid.recid = t.recid ORDER BY t.depart_time_timestamp)
			SELECT t.*, cte.trip_link INTO #trip_ingredient
				FROM HHSurvey.trip AS t JOIN cte ON 1 = 1
				WHERE EXISTS (SELECT 1 FROM #recid_list AS rid WHERE rid.recid = t.recid);
			
			DECLARE @person_id decimal(19,0) = NULL
			SET @person_id = (SELECT person_id FROM #trip_ingredient GROUP BY person_id);

			EXECUTE HHSurvey.link_trips;
			EXECUTE HHSurvey.tripnum_update @person_id;
			EXECUTE HHSurvey.generate_error_flags @person_id;
			DROP TABLE IF EXISTS #recid_list;
			DROP TABLE IF EXISTS #trip_ingredient;
			SET @person_id = NULL
			SET @recid_list = NULL
			END
			GO

	-- UNLINKING (i.e. reverse the link procedure given above)

			DROP PROCEDURE IF EXISTS HHSurvey.unlink_via_id;
			GO
			CREATE PROCEDURE HHSurvey.unlink_via_id
				@ref_recid int = NULL
			AS BEGIN
				DECLARE @ref_person_id decimal(19,0) = NULL,
						@ref_starttime DATETIME2 = NULL,
						@ref_endtime DATETIME2 = NULL,
						@ref_triplink int = NULL
				SET NOCOUNT OFF;

				SET @ref_person_id = (SELECT t.person_id FROM HHSurvey.Trip AS t WHERE t.recid = @ref_recid);
				SET @ref_starttime = (SELECT t.depart_time_timestamp FROM HHSurvey.Trip AS t WHERE t.recid = @ref_recid);
				SET @ref_endtime = (SELECT t.arrival_time_timestamp FROM HHSurvey.Trip AS t WHERE t.recid = @ref_recid);

				WITH cte AS (SELECT tid.person_id, tid.trip_link, min(tid.depart_time_timestamp) AS start_time, max(tid.arrival_time_timestamp) AS end_time 
							FROM HHSurvey.trip_ingredients_done AS tid WHERE tid.person_id = @ref_person_id GROUP BY tid.person_id, tid.trip_link)
				SELECT cte.trip_link INTO #FoundTripLink
					FROM cte JOIN HHSurvey.Trip AS t ON cte.start_time = t.depart_time_timestamp AND cte.end_time = t.arrival_time_timestamp AND cte.person_id = t.person_id
					GROUP BY cte.trip_link;

				SET @ref_triplink = (SELECT trip_link FROM #FoundTripLink)

				IF (@ref_triplink > 0 )
					BEGIN

					DELETE FROM HHSurvey.Trip WHERE recid = @ref_recid;
					ALTER TABLE HHSurvey.trip DISABLE TRIGGER tr_trip;

					SET IDENTITY_INSERT HHSurvey.Trip ON;
					INSERT INTO HHSurvey.Trip (
						 [recid]
						,[hhid]
						,[person_id]
						,[pernum]
						,[tripid]
						,[tripnum]
						,[traveldate]
						,[daynum]
						,[copied_trip]
						,[svy_complete]
						,[depart_time_timestamp]
						,[arrival_time_timestamp]
						,[origin_lat]
						,[origin_lng]
						,[origin_label]
						,[dest_lat]
						,[dest_lng]
						,[dest_label]
						,[distance_miles]
						,[travel_time]
						,[hhmember1]
						,[hhmember2]
						,[hhmember3]
						,[hhmember4]
						,[hhmember5]
						,[hhmember6]
						,[hhmember7]
						,[hhmember8]
						,[hhmember9]
						,[travelers_hh]
						,[travelers_nonhh]
						,[travelers_total]
						,[origin_purpose]
						,origin_purpose_cat
						,[dest_purpose]
						,[dest_purpose_other]
						,dest_purpose_cat			
						,[mode_1]
						,[mode_2]
						,[mode_3]
						,[mode_4]
						,mode_type			
						,[driver]
						,[change_vehicles]
						,[is_access]
						,[is_egress]
						,[has_access]
						,[has_egress]			
						,[mode_acc]
						,[mode_egr]			
						,[speed_mph]
						,[trace_quality_flag]
						,[user_added]
						,[user_merged]
						,[user_split]
						,[analyst_merged]
						,[analyst_split]
						,[analyst_split_loop]
						,[day_id]
						,[travel_day]
						,[travel_date] 
						,[travel_dow] 
						,[day_iscomplete]
						,[depart_date] 
						,[depart_dow]
						,[depart_time_hour]
						,[depart_time_minute]
						,[depart_time_second]
						,[arrive_date]
						,[arrive_dow]
						,[arrival_time_hour]
						,[arrival_time_minute]
						,[arrival_time_second]
						,[o_in_region]
						,[o_puma10]
						,[o_bg]
						,[d_in_region]
						,[d_puma10]
						,[d_bg]
						,[distance_meters]
						,[duration_minutes]
						,[duration_seconds]
						,[speed_flag]
						,[dwell_mins]
						,[days_first_trip] 
						,[days_last_trip]
						,[mode_other_specify]
						,[is_transit]
						,[hhmember10]
						,[hhmember11]
						,[hhmember12]
						,[taxi_cost_known]
						,[taxi_cost_int]
						,[flag_teleport]
						,[pt_density]
						,[point_dist_index]
						,[trip_weight]
						,[survey_year] 
						,[day_is_complete_a]
						,[day_is_complete_b]
						,[hh_day_iscomplete]
						,[hh_day_iscomplete_a]
						,[hh_day_iscomplete_b]
						,dest_is_home
						,dest_is_work
						,modes
						,psrc_inserted
						,revision_code)
					SELECT recid
						,[hhid]
						,[person_id]
						,[pernum]
						,[tripid]
						,[tripnum]
						,[traveldate]
						,[daynum]
						,[copied_trip]
						,[svy_complete]
						,[depart_time_timestamp]
						,[arrival_time_timestamp]
						,[origin_lat]
						,[origin_lng]
						,[origin_label]
						,[dest_lat]
						,[dest_lng]
						,[dest_label]
						,[distance_miles]
						,[travel_time]
						,[hhmember1]
						,[hhmember2]
						,[hhmember3]
						,[hhmember4]
						,[hhmember5]
						,[hhmember6]
						,[hhmember7]
						,[hhmember8]
						,[hhmember9]
						,[travelers_hh]
						,[travelers_nonhh]
						,[travelers_total]
						,[origin_purpose]
						,origin_purpose_cat
						,[dest_purpose]
						,[dest_purpose_other]
						,dest_purpose_cat			
						,[mode_1]
						,[mode_2]
						,[mode_3]
						,[mode_4]
						,mode_type			
						,[driver]
						,[change_vehicles]
						,[is_access]
						,[is_egress]
						,[has_access]
						,[has_egress]			
						,[mode_acc]
						,[mode_egr]			
						,[speed_mph]
						,[trace_quality_flag]
						,[user_added]
						,[user_merged]
						,[user_split]
						,[analyst_merged]
						,[analyst_split]
						,[analyst_split_loop]
						,[day_id]
						,[travel_day]
						,[travel_date] 
						,[travel_dow] 
						,[day_iscomplete]
						,[depart_date] 
						,[depart_dow]
						,[depart_time_hour]
						,[depart_time_minute]
						,[depart_time_second]
						,[arrive_date]
						,[arrive_dow]
						,[arrival_time_hour]
						,[arrival_time_minute]
						,[arrival_time_second]
						,[o_in_region]
						,[o_puma10]
						,[o_bg]
						,[d_in_region]
						,[d_puma10]
						,[d_bg]
						,[distance_meters]
						,[duration_minutes]
						,[duration_seconds]
						,[speed_flag]
						,[dwell_mins]
						,[days_first_trip] 
						,[days_last_trip]
						,[mode_other_specify]
						,[is_transit]
						,[hhmember10]
						,[hhmember11]
						,[hhmember12]
						,[taxi_cost_known]
						,[taxi_cost_int]
						,[flag_teleport]
						,[pt_density]
						,[point_dist_index]
						,[trip_weight]
						,[survey_year] 
						,[day_is_complete_a]
						,[day_is_complete_b]
						,[hh_day_iscomplete]
						,[hh_day_iscomplete_a]
						,[hh_day_iscomplete_b]
						,dest_is_home
						,dest_is_work
						,modes
						,psrc_inserted
						,revision_code
						FROM HHSurvey.trip_ingredients_done AS tid 
						WHERE tid.person_id = @ref_person_id AND tid.trip_link = @ref_triplink;

					DELETE tid
					FROM HHSurvey.trip_ingredients_done AS tid 
					WHERE tid.person_id = @ref_person_id AND tid.trip_link = @ref_triplink;

					EXECUTE HHSurvey.recalculate_after_edit @ref_person_id;
					EXECUTE HHSurvey.generate_error_flags @ref_person_id;
				END
					
				DROP TABLE IF EXISTS #FoundTripLink;

				ALTER TABLE HHSurvey.trip ENABLE TRIGGER [tr_trip];
				SET IDENTITY_INSERT HHSurvey.Trip OFF;
			
			END
			GO

	--SPLIT TRIP USING TRACE DATA
		/*	Also shortens too-long trips when intermediate stop distance is short */
		/*	NOT CURRENTLY USING TRACES FOR 2021 dataset
			DROP PROCEDURE IF EXISTS HHSurvey.split_trip_from_traces;
			GO
			CREATE PROCEDURE HHSurvey.split_trip_from_traces
				@target_recid int = NULL
			AS BEGIN
			SET NOCOUNT ON; 
			DROP TABLE IF EXISTS #tmpSplit;

			WITH cte AS
			(SELECT t.recid, t.tripid, t.person_id, t.origin_geog, t.dest_geog, t.depart_time_timestamp, t.arrival_time_timestamp, t.distance_miles
				FROM HHSurvey.Trip AS t WHERE t.recid = @target_recid AND t.hhgroup = 1)
			SELECT TOP 1 cte.*, c.lat, c.lng, c.point_geog, c.traceid, c.collected_at AS midpoint_arrival_timestamp, cnxt.collected_at AS midpoint_depart_timestamp,
				c.point_geog.STDistance(cte.origin_geog)/1609.344 AS cfmiles2start, c.point_geog.STDistance(cte.dest_geog)/1609.344 AS cfmiles2end,
				cte.distance_miles * (c.point_geog.STDistance(cte.origin_geog) / (c.point_geog.STDistance(cte.origin_geog) + c.point_geog.STDistance(cte.dest_geog))) AS to_midpoint_distance_approx,
				cte.distance_miles * (1- c.point_geog.STDistance(cte.origin_geog) / (c.point_geog.STDistance(cte.origin_geog) + c.point_geog.STDistance(cte.dest_geog))) AS from_midpoint_distance_approx
			INTO #tmpSplit
			FROM HHSurvey.Trace AS c 
				JOIN cte ON c.tripid = cte.tripid 
				JOIN HHSurvey.Trace AS cnxt ON c.traceid + 1 = cnxt.traceid AND c.tripid = cnxt.tripid
				WHERE DATEDIFF(Minute, c.collected_at, cnxt.collected_at) > 14 AND c.collected_at > cte.depart_time_timestamp AND c.collected_at < cte.arrival_time_timestamp AND cte.dest_geog.STDistance(cte.origin_geog) > 0
				ORDER BY DATEDIFF(Second, c.collected_at, cnxt.collected_at) DESC;

			IF (SELECT cfmiles2start FROM #tmpSplit) < 0.1
				BEGIN
				UPDATE t 
				SET t.depart_time_timestamp = DATEADD(Minute, -3, x.midpoint_depart_timestamp),  --(3 min adjustment to counteract the standard trace lag)
					t.revision_code = CONCAT(t.revision_code, '14,'),
					t.psrc_comment = NULL
				FROM HHSurvey.Trip AS t JOIN #tmpSplit AS x ON t.recid = x.recid;
				END

			ELSE IF (SELECT cfmiles2end FROM #tmpSplit) < 0.1
				BEGIN
				UPDATE t 
				SET t.arrival_time_timestamp = x.midpoint_arrival_timestamp,
					t.revision_code = CONCAT(t.revision_code, '14,'),
					t.psrc_comment = NULL
				FROM HHSurvey.Trip AS t JOIN #tmpSplit AS x ON t.recid = x.recid;
				END

			ELSE IF ((SELECT cfmiles2start FROM #tmpSplit) > 0.1 AND (SELECT cfmiles2end FROM #tmpSplit) > 0.1)
				BEGIN
				INSERT INTO HHSurvey.Trip (hhid, person_id, pernum, hhgroup, travelers_hh, travelers_nonhh, travelers_total, modes, mode_1, 
					hhmember1, hhmember2, hhmember3, hhmember4, hhmember5, hhmember6, hhmember7, hhmember8, hhmember9, 
					dest_purpose,depart_time_timestamp, 
					arrival_time_timestamp, 
					distance_miles,
					origin_lat, origin_lng, origin_geog, 
					dest_lat, dest_lng, dest_geog, dest_is_home, dest_is_work,
					revision_code, psrc_inserted)			
				SELECT  t.hhid, t.person_id, t.pernum, t.hhgroup, t.travelers_hh, t.travelers_nonhh, t.travelers_total, t.modes, t.mode_1,
						t.hhmember1, t.hhmember2, t.hhmember3, t.hhmember4, t.hhmember5, t.hhmember6, t.hhmember7, t.hhmember8, t.hhmember9, 
					t.dest_purpose, DATEADD(Minute, -3, x.midpoint_depart_timestamp) AS depart_time_timestamp, 
					t.arrival_time_timestamp, 
					x.from_midpoint_distance_approx AS distance_miles,
					x.lat AS origin_lat, x.lng AS origin_lng, x.point_geog AS origin_geog, 
					t.dest_lat, t.dest_lng, t.dest_geog, t.dest_is_home, t.dest_is_work,
					14 AS revision_code, 1 AS psrc_inserted
					FROM HHSurvey.Trip AS t JOIN #tmpSplit AS x ON t.recid = x.recid
				
				UPDATE t 
				SET t.arrival_time_timestamp = x.midpoint_arrival_timestamp,
					t.dest_lat = x.lat,
					t.dest_lng = x.lng,
					t.dest_geog = x.point_geog,
					t.distance_miles = x.to_midpoint_distance_approx,
					t.dest_purpose = 97,
					t.revision_code = CONCAT(t.revision_code, '15,'),
					t.psrc_comment = NULL,
					t.dest_is_home = NULL,
					t.dest_is_work = NULL
				FROM HHSurvey.Trip AS t JOIN #tmpSplit AS x ON t.recid = x.recid;
				END

			DECLARE @split_person_id decimal (19,0) = (SELECT x.person_id FROM #tmpSplit AS x)
			DROP TABLE #tmpSplit;
			EXECUTE HHSurvey.recalculate_after_edit @split_person_id;
			EXECUTE HHSurvey.generate_error_flags @split_person_id;

			END
	*/
	--ADD TRIP, details optional
		/*	Generates a blank trip, or populates a trip with the information from another trip */

		DROP PROCEDURE IF EXISTS HHSurvey.insert_new_trip;
		GO
		CREATE PROCEDURE HHSurvey.insert_new_trip
			@target_person_id decimal = NULL, @target_recid int = NULL
		AS BEGIN
		IF @target_recid IS NOT NULL 
			BEGIN
			INSERT INTO HHSurvey.Trip (hhid, person_id, pernum, psrc_inserted, tripnum,
				dest_lat, dest_lng, dest_label, origin_lat, origin_lng, depart_time_timestamp, arrival_time_timestamp, /*travel_time,*/ distance_miles,
				dest_purpose, dest_purpose_cat, modes, mode_acc, mode_1, /*mode_2, mode_3, mode_4, */mode_egr, travelers_hh, travelers_nonhh, travelers_total)
			SELECT p.hhid, p.person_id, p.pernum, 1, 0,
				t.dest_lat, t.dest_lng, t.dest_label, t.origin_lat, t.origin_lng, t.depart_time_timestamp, t.arrival_time_timestamp, /*t.travel_time,*/ t.distance_miles,
				t.dest_purpose, t.dest_purpose_cat, t.modes, t.mode_acc, t.mode_1, /*mode_2, mode_3, mode_4, */t.mode_egr, t.travelers_hh, t.travelers_nonhh, t.travelers_total
			FROM HHSurvey.Person AS p CROSS JOIN HHSurvey.Trip AS t WHERE p.person_id = @target_person_id AND t.recid = @target_recid;
			END
		ELSE
			BEGIN
			INSERT INTO HHSurvey.Trip (hhid, person_id, pernum, psrc_inserted)
			SELECT p.hhid, p.person_id, p.pernum, 1
			FROM HHSurvey.Person AS p WHERE p.person_id = @target_person_id;
			END

		EXECUTE HHSurvey.recalculate_after_edit @target_person_id;
		EXECUTE HHSurvey.generate_error_flags @target_person_id;
		END

	--ADD REVERSE TRIP

		DROP PROCEDURE IF EXISTS HHSurvey.insert_reverse_trip;
		GO
		CREATE PROCEDURE HHSurvey.insert_reverse_trip
			@target_recid int, @starttime nvarchar(5)
		AS BEGIN
		IF @target_recid IS NOT NULL 
			BEGIN

			DECLARE @target_person_id decimal(19,0) = NULL;
			SET @target_person_id = (SELECT x.person_id FROM HHSurvey.Trip AS x WHERE x.recid=@target_recid);

			WITH cte AS (SELECT DATETIME2FROMPARTS(YEAR(t0.arrival_time_timestamp), 
			   					  MONTH(t0.arrival_time_timestamp), 
								  DAY(t0.arrival_time_timestamp), 
								  CAST(Elmer.dbo.rgx_replace(@starttime,'(\d?\d):\d\d',LTRIM('$1'),1) AS int), 
								  CAST(RIGHT(Elmer.dbo.rgx_replace(@starttime,':(\d\d)$',LTRIM('$1'),1),2) AS int), 0 ,0 ,0) AS depart_time_timestamp,
								DATEDIFF(minute, t0.depart_time_timestamp, t0.arrival_time_timestamp) AS travel_time_elapsed,
								t0.person_id, t0.recid 
							FROM HHSurvey.Trip AS t0 WHERE t0.recid=@target_recid)
			INSERT INTO HHSurvey.Trip (hhid, person_id, pernum, psrc_inserted, tripnum,
				dest_lat, dest_lng, dest_label, origin_lat, origin_lng, origin_label, depart_time_timestamp, arrival_time_timestamp, /*travel_time,*/ distance_miles,
				dest_purpose, dest_purpose_cat, origin_purpose, origin_purpose_cat, modes, mode_acc, mode_1, /*mode_2, mode_3, mode_4, */mode_egr, travelers_hh, travelers_nonhh, travelers_total)
			SELECT t.hhid, t.person_id, t.pernum, 1, 0,
				t.origin_lat, t.origin_lng, t.origin_label, t.dest_lat, t.dest_lng, t.dest_label,
				cte.depart_time_timestamp, DATEADD(minute, cte.travel_time_elapsed, cte.depart_time_timestamp) AS arrival_time_timestamp,
				 /*t.travel_time,*/ t.distance_miles,
				t.origin_purpose, t.origin_purpose_cat, t.dest_purpose, t.dest_purpose_cat, t.modes, t.mode_acc, t.mode_1, /*mode_2, mode_3, mode_4, */t.mode_egr, t.travelers_hh, t.travelers_nonhh, t.travelers_total
			FROM HHSurvey.Trip AS t JOIN cte ON t.recid=cte.recid;

			EXECUTE HHSurvey.recalculate_after_edit @target_person_id;
			EXECUTE HHSurvey.generate_error_flags @target_person_id;
			END
		END

	--ADD RETURN HOME TRIP
		/*	Uses home location determined on file; needs to be amended for live API distance/travel time pull (currently uses stored API result) */

		DROP PROCEDURE IF EXISTS HHSurvey.insert_return_home;
		GO

		CREATE PROCEDURE HHSurvey.insert_return_home
		AS BEGIN
		DROP TABLE IF EXISTS tmpApi2Home;
		CREATE TABLE tmpApi2Home(rownum int identity(1,1),
								 init_recid int,
								 new_recid int,
								 hhid int, 
								 person_id decimal(19,0),
								 pernum int,
								 api_response nvarchar(255), 
								 depart_time_timestamp datetime2,
								 api_minutes float, 
								 origin_geog geography, 
							     home_geog geography, 
								 mode_1 int, 
								 travelers_hh int, 
								 travelers_nonhh int, 
								 travelers_total int, 
								 api_miles float);

		
		INSERT INTO tmpApi2Home(init_recid, hhid, person_id, pernum, api_response, mode_1, depart_time_timestamp, origin_geog, home_geog, travelers_hh, travelers_nonhh, travelers_total)
		SELECT t.recid AS init_recid, t.hhid, t.person_id, t.pernum,
			   Elmer.dbo.route_mi_min(t.dest_geog.Long, t.dest_geog.Lat, h.home_geog.Long, h.home_geog.Lat, 
			   						  CASE WHEN p.age <5 AND t.dest_purpose=6 AND t.dest_geog.STDistance(h.home_geog) < 1500 THEN 'walking' ELSE 'driving' END,'AlrP-dw5WRAoOohAABv5EhKtvgp_plo8hnfBM-FJsfvi9UdFCe0AdqT7oURMTGLC') AS api_response,
			   CASE WHEN p.age <5 AND t.dest_purpose=6 AND t.dest_geog.STDistance(h.home_geog) < 1500 THEN 1 ELSE 16 END	AS mode_1, 
			   DATETIME2FROMPARTS(YEAR(t.arrival_time_timestamp), 
			   					  MONTH(t.arrival_time_timestamp), 
								  DAY(t.arrival_time_timestamp), 
								  CAST(Elmer.dbo.rgx_replace(t.psrc_comment,'ADD RETURN HOME( \d?\d):\d\d.*',LTRIM('$1'),1) AS int), 
								  CAST(RIGHT(Elmer.dbo.rgx_extract(t.psrc_comment,':\d\d',1),2) AS int), 0 ,0 ,0) AS depart_time_timestamp,
			   t.dest_geog,
			   h.home_geog,
			   t.travelers_hh, 
			   t.travelers_nonhh,
			   t.travelers_total
			FROM HHSurvey.Trip AS t JOIN HHSurvey.Household AS h ON t.hhid=h.hhid JOIN HHSurvey.Person AS p ON t.person_id=p.person_id
			WHERE Elmer.dbo.rgx_find(t.psrc_comment, 'ADD RETURN HOME \d?\d:\d\d',1) =1;

		WITH cte AS (SELECT max(recid) AS max_recid FROM HHSurvey.Trip)	
		UPDATE ta
			SET new_recid = (cte.max_recid + ta.rownum),
				api_miles = CAST(Elmer.dbo.rgx_replace(api_response,'^(.*),.*','$1',1) AS float), 
		        api_minutes = CAST(Elmer.dbo.rgx_replace(api_response,'.*,(.*)$','$1',1) AS float)
			FROM tmpApi2Home AS ta JOIN cte ON 1=1;		

		SET IDENTITY_INSERT hhts_cleaning.HHSurvey.Trip ON;

		INSERT INTO	HHSurvey.Trip (recid, hhid, person_id, pernum, psrc_inserted, tripnum,
				dest_lat, dest_lng, dest_label, origin_lat, origin_lng, depart_time_timestamp, arrival_time_timestamp, distance_miles,
				dest_purpose, mode_1, travelers_hh, travelers_nonhh, travelers_total)
		SELECT  ta.new_recid AS recid, ta.hhid, ta.person_id, ta.pernum, 1, 0,
				ta.home_geog.Lat, ta.home_geog.Long, 'HOME', ta.origin_geog.Lat, ta.origin_geog.Long, depart_time_timestamp, 
				DATEADD(Minute, ROUND(ta.api_minutes,0), ta.depart_time_timestamp) AS arrival_time_timestamp,
				ta.api_miles, 1 AS dest_purpose, ta.mode_1, ta.travelers_hh, ta.travelers_nonhh, ta.travelers_total
			FROM tmpApi2Home AS ta;

		SET IDENTITY_INSERT hhts_cleaning.HHSurvey.Trip OFF;

		UPDATE t 
			SET t.psrc_comment = Elmer.dbo.rgx_replace(t.psrc_comment, 'ADD RETURN HOME \d?\d:\d\d','',1) 
			FROM HHSurvey.Trip AS t JOIN tmpApi2Home AS ta ON t.recid = ta.init_recid;
		UPDATE nxt
		 	SET nxt.origin_purpose=1, nxt.origin_lat=ta.home_geog.Lat, nxt.origin_lng=ta.home_geog.Long
			FROM HHSurvey.Trip AS t JOIN HHSurvey.Trip AS nxt ON t.person_id = nxt.person_id AND t.tripnum + 1 = nxt.tripnum JOIN tmpApi2Home AS ta ON t.recid = ta.new_recid;

		EXECUTE HHSurvey.recalculate_after_edit;
		EXECUTE HHSurvey.tripnum_update
		EXECUTE HHSurvey.generate_error_flags;	
		END
		GO

	--Generate GUI recordset to show activity of other household members

		DROP PROCEDURE IF EXISTS HHSurvey.find_your_family;
		GO
		CREATE PROCEDURE HHSurvey.find_your_family 
			@target_recid numeric NULL --provide recid of reference member

		AS BEGIN
		SET NOCOUNT OFF;
		WITH cte_ref AS
				(SELECT t0.hhid, t0.depart_time_timestamp, t0.arrival_time_timestamp, t0.pernum, t0.driver
					FROM HHSurvey.Trip AS t0 
					WHERE t0.recid = @target_recid),
			cte_mobile AS(
				SELECT 	t3.hhid, t3.pernum, ac1.agedesc,
						'enroute' AS member_status, 
						CONCAT(CAST(t3.origin_lat AS NVARCHAR(20)),', ',CAST(t3.origin_lng AS NVARCHAR(20))) AS prior_location,
						CONCAT(CAST(t3.dest_lat AS NVARCHAR(20)),', ',CAST(t3.dest_lng AS NVARCHAR(20))) AS next_destination, 
						CONCAT((CASE WHEN t3.pernum = cte_ref.pernum THEN 'reference person - ' ELSE '' END),
							CASE WHEN t3.driver = 1 THEN 'driver' 	
								WHEN EXISTS (SELECT 1 FROM HHSurvey.AutoModes AS am WHERE t3.mode_1 = am.mode_id) THEN 'passenger' 
								WHEN EXISTS (SELECT 1 FROM HHSurvey.TransitModes AS tm WHERE t3.mode_1 = tm.mode_id) THEN 'transit rider'
								WHEN t3.mode_1 = 1 THEN 'pedestrian'
								ELSE 'other' END) AS rider_status
					FROM HHSurvey.Trip AS t3
					JOIN cte_ref ON t3.hhid = cte_ref.hhid
					JOIN HHSurvey.Person AS p1 ON t3.person_id = p1.person_id LEFT JOIN HHSurvey.AgeCategories AS ac1 ON ac1.AgeCode = p1.age
					WHERE ((cte_ref.depart_time_timestamp BETWEEN t3.depart_time_timestamp AND t3.arrival_time_timestamp) 
							OR (cte_ref.arrival_time_timestamp BETWEEN t3.depart_time_timestamp AND t3.arrival_time_timestamp))),
			cte_static AS
				(SELECT t1.hhid, t1.pernum, ac2.agedesc,
						'at rest' AS member_status, 
						CONCAT(CAST(t1.dest_lat AS NVARCHAR(20)),', ',CAST(t1.dest_lng AS NVARCHAR(20))) AS prior_location,
						CONCAT(CAST(t2.dest_lat AS NVARCHAR(20)),', ',CAST(t2.dest_lng AS NVARCHAR(20))) AS next_destination,
						'n/a' AS rider_status
					FROM HHSurvey.Trip AS t1
					LEFT JOIN HHsurvey.Trip AS t2 ON t1.person_id = t2.person_id AND t1.tripnum + 1 = t2.tripnum
					JOIN cte_ref ON t1.hhid = cte_ref.hhid AND NOT EXISTS (SELECT 1 FROM cte_mobile WHERE cte_mobile.pernum = t1.pernum)
					JOIN HHSurvey.Person AS p2 ON t2.person_id = p2.person_id LEFT JOIN HHSurvey.AgeCategories AS ac2 ON ac2.AgeCode = p2.age
					WHERE (cte_ref.depart_time_timestamp > t1.arrival_time_timestamp AND cte_ref.arrival_time_timestamp < t2.depart_time_timestamp)
						OR (cte_ref.depart_time_timestamp > t1.arrival_time_timestamp AND t2.depart_time_timestamp IS NULL)
			)
		SELECT * FROM cte_mobile UNION SELECT * FROM cte_static
		ORDER BY pernum;
		END
		GO

	--Generate GUI recordset showing traces for the specified trip
	/* NOT USING TRACES IN 2021
		DROP PROCEDURE IF EXISTS HHSurvey.trace_this_trip;
		GO
		CREATE PROCEDURE HHSurvey.trace_this_trip
			@target_recid numeric NULL --provide recid of reference member
		
		AS BEGIN
		SET NOCOUNT OFF;
		WITH cte AS
		(SELECT t.tripid, t.recid FROM HHSurvey.Trip AS t WHERE t.recid = @target_recid)
		SELECT c.traceid, CONVERT(NVARCHAR, c.collected_at, 22) AS timepoint, Round(DATEDIFF(Second, c.collected_at, cnxt.collected_at)/60,1) AS minutes_btwn, ROUND(c.point_geog.STDistance(cnxt.point_geog)/1609,2) AS miles_btwn, CONCAT(CAST(c.lat AS VARCHAR(20)),', ',CAST(c.lng AS VARCHAR(20))) AS coords
		FROM HHSurvey.Trace AS c JOIN cte ON c.tripid = cte.tripid LEFT JOIN HHSurvey.Trace AS cnxt ON c.traceid + 1 = cnxt.traceid AND c.tripid = cnxt.tripid
		WHERE cte.recid = @target_recid
		ORDER BY c.collected_at ASC;
		END
		GO

		DROP PROCEDURE IF EXISTS HHSurvey.examine_link_ingredients;
		GO
		CREATE PROCEDURE HHSurvey.examine_link_ingredients
			@target_recid numeric NULL --provide recid of reference member
		
		AS BEGIN
		SET NOCOUNT OFF;
		WITH cte AS
		(SELECT tid0.person_id, tid0.trip_link FROM HHSurvey.trip_ingredients_done AS tid0 WHERE tid0.recid = @target_recid)
		SELECT tid.recid, tid.person_id, tid.hhid, tid.tripnum, tid.daynum, tid.mode_1,
			FORMAT(tid.depart_time_timestamp,N'hh\:mm tt','en-US') AS depart_dhm,
			FORMAT(tid.arrival_time_timestamp,N'hh\:mm tt','en-US') AS arrive_dhm,
			ROUND(tid.distance_miles,1) AS miles,
			ROUND(tid.speed_mph,1) AS mph, 
			CONCAT(tid.origin_purpose, '-',tpo.purpose) AS origin_purpose, tid.dest_label, CONCAT(tid.dest_purpose, '-',tpd.purpose) AS dest_purpose, 
				CONCAT(CONVERT(varchar(30), (DATEDIFF(mi, tid.arrival_time_timestamp, t2.depart_time_timestamp) / 60)),'h',RIGHT('00'+CONVERT(varchar(30), (DATEDIFF(mi, tid.arrival_time_timestamp, CASE WHEN t2.recid IS NULL 
										THEN DATETIME2FROMPARTS(DATEPART(year,tid.arrival_time_timestamp),DATEPART(month,tid.arrival_time_timestamp),DATEPART(day,tid.arrival_time_timestamp),3,0,0,0,0) 
										ELSE t2.depart_time_timestamp END) % 60)),2),'m') AS duration_at_dest,
				CONCAT(CAST(tid.origin_lat AS VARCHAR(20)),', ',CAST(tid.origin_lng AS VARCHAR(20))) AS origin_coord,						 
				CONCAT(CAST(tid.dest_lat AS VARCHAR(20)),', ',CAST(tid.dest_lng AS VARCHAR(20))) AS dest_coord,
				tid.revision_code AS rc, tid.psrc_comment AS elevate_issue
			FROM HHSurvey.trip_ingredients_done AS tid 
				JOIN cte ON tid.trip_link = cte.trip_link AND tid.person_id = cte.person_id
				LEFT JOIN HHSurvey.trip_ingredients_done as t2 ON tid.person_id = t2.person_id AND (tid.tripnum+1) = t2.tripnum
				LEFT JOIN HHSurvey.trip_purpose AS tpo ON tid.origin_purpose=tpo.purpose_id
				LEFT JOIN HHSurvey.trip_purpose AS tpd ON tid.dest_purpose=tpd.purpose_id
		ORDER BY tid.tripnum ASC;
		END
		GO
	*/
	--Generate GUI recordset showing linked trip ingredients

		DROP PROCEDURE IF EXISTS HHSurvey.link_trip_click;
		GO
		CREATE PROCEDURE HHSurvey.link_trip_click
			@ref_recid int = NULL
		
			AS BEGIN
		SET NOCOUNT OFF;
		DECLARE @recid_list nvarchar(255) = NULL
		IF (SELECT Elmer.dbo.rgx_find(Elmer.dbo.TRIM(t.psrc_comment),'^(\d+,?)+$',1) FROM HHSurvey.Trip AS t WHERE t.recid = @ref_recid) = 1
			BEGIN
			SELECT @recid_list = (SELECT Elmer.dbo.TRIM(t.psrc_comment) FROM HHSurvey.Trip AS t WHERE t.recid = @ref_recid)
			EXECUTE HHSurvey.link_trip_via_id @recid_list;
			SELECT @recid_list = NULL, @ref_recid = NULL
			END
		END
		GO
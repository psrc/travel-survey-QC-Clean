/* Final scripted changes to Trip table through Rulesy before switching to manual edits 
-- Can be expanded as necessary 
*/

DROP PROCEDURE IF EXISTS HHSurvey.cleanup_trips;
GO

CREATE PROCEDURE HHSurvey.cleanup_trips
AS BEGIN

	-- Snap origin points to prior destination, when proximate
	UPDATE t
	SET t.origin_geog=prev_t.dest_geog,
		t.origin_lat=prev_t.dest_geog.Lat,
		t.origin_lng=prev_t.dest_geog.Long
		FROM HHSurvey.Trip AS t JOIN HHSurvey.Trip AS prev_t ON t.person_id=prev_t.person_id AND t.tripnum -1 = prev_t.tripnum
		WHERE t.origin_geog.STEquals(prev_t.dest_geog)=0 AND t.origin_geog.STDistance(prev_t.dest_geog)<100;
END
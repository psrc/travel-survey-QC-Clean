
UPDATE t SET t.mode_acc=CASE WHEN t.mode_acc IN(4,5,8,9,10,11,12,16,17,22,33,34) THEN 3 
                             WHEN t.mode_acc IN(66,67,68,69,81) THEN 2 
                             WHEN t.mode_acc IN(18,37) THEN 4
                             WHEN t.mode_acc=60 THEN 6
                             WHEN t.mode_acc IN(78,79,82) THEN 9 END
FROM hhts_cleaning.HHSurvey.Trip AS t JOIN HouseholdTravelSurvey2023.combined_data.v_trip AS v ON t.initial_tripid=v.tripid
WHERE t.mode_acc <> 995 AND t.mode_acc NOT IN(1,2,3,97) AND t.mode_acc<>v.mode_acc; 

UPDATE t SET t.mode_egr=CASE WHEN t.mode_egr IN(4,5,8,9,10,11,12,16,17,22,33,34) THEN 3 
                             WHEN t.mode_egr IN(66,67,68,69,81) THEN 2 
                             WHEN t.mode_egr IN(18,37) THEN 4
                             WHEN t.mode_egr=60 THEN 6
                             WHEN t.mode_egr IN(78,79,82) THEN 9 END
FROM hhts_cleaning.HHSurvey.Trip AS t JOIN HouseholdTravelSurvey2023.combined_data.v_trip AS v ON t.initial_tripid=v.tripid
WHERE t.mode_egr <> 995 AND t.mode_egr NOT IN(1,2,3,97) AND t.mode_egr<>v.mode_egr;

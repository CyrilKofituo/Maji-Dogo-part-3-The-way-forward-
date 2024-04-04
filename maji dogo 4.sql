-- joining the location and visits table
select
	town_name,
	province_name,
	visit_count,
    visits.location_id
from md_water_services.visits
JOIN
	md_water_services.location
ON
	location.location_id = visits.location_id ;
    
  -- adding the water source table  
SELECT
	town_name,
	province_name,
    type_of_water_source,
    time_in_queue,
    location_type,
    number_of_people_served
FROM md_water_services.visits
JOIN
	md_water_services.water_source
ON 
water_source.source_id =visits.source_id
JOIN
	md_water_services.location
ON
	location.location_id = visits.location_id
WHERE
visits.visit_count = 1;

-- adding the well pollution result column
SELECT
	town_name,
	province_name,
    type_of_water_source,
    time_in_queue,
    location_type,
    number_of_people_served,
    results
FROM md_water_services.visits
JOIN
	md_water_services.water_source
ON 
water_source.source_id =visits.source_id
JOIN
	md_water_services.location
ON
	location.location_id = visits.location_id 
LEFT JOIN
	well_pollution
ON 
	well_pollution.source_id = visits.source_id
WHERE
visits.visit_count = 1;


-- creating the combined analysis table
CREATE VIEW combined_analysis_table AS
SELECT
	town_name,
	province_name,
    type_of_water_source,
    time_in_queue,
    location_type,
    number_of_people_served,
    results
FROM md_water_services.visits
JOIN
	md_water_services.water_source
ON 
water_source.source_id =visits.source_id
JOIN
	md_water_services.location
ON
	location.location_id = visits.location_id 
LEFT JOIN
	well_pollution
ON 
	well_pollution.source_id = visits.source_id
WHERE
visits.visit_count = 1;



-- This CTE calculates the population of each province
WITH province_totals AS ( 
SELECT
province_name,
SUM(number_of_people_served) AS total_ppl_serv
FROM
combined_analysis_table
GROUP BY
province_name)
SELECT
combined_analysis_table.province_name,
-- These case statements create columns for each type of source.
-- The results are aggregated and percentages are calculated
ROUND((SUM(CASE WHEN type_of_water_source = 'river'
THEN number_of_people_served ELSE 0 END) * 100.0 / province_totals.total_ppl_serv), 0) AS river,
ROUND((SUM(CASE WHEN type_of_water_source = 'shared_tap'
THEN number_of_people_served ELSE 0 END) * 100.0 / province_totals.total_ppl_serv), 0) AS shared_tap,
ROUND((SUM(CASE WHEN type_of_water_source = 'tap_in_home'
THEN number_of_people_served ELSE 0 END) * 100.0 / province_totals.total_ppl_serv), 0) AS tap_in_home,
ROUND((SUM(CASE WHEN type_of_water_source = 'tap_in_home_broken'
THEN number_of_people_served ELSE 0 END) * 100.0 / province_totals.total_ppl_serv), 0) AS tap_in_home_broken,
ROUND((SUM(CASE WHEN type_of_water_source = 'well'
THEN number_of_people_served ELSE 0 END) * 100.0 / province_totals.total_ppl_serv), 0) AS well
FROM
combined_analysis_table
JOIN
province_totals  ON combined_analysis_table.province_name = province_totals.province_name
GROUP BY
combined_analysis_table.province_name
ORDER BY
combined_analysis_table.province_name;


-- This TEMPORARY TABLE calculates the population of each town,Since there are two Harare towns, we have to group by province_name and town_name
CREATE TEMPORARY TABLE town_aggregated_water_access
WITH town_totals AS ( 
SELECT province_name, town_name, SUM(number_of_people_served) AS total_ppl_serv
FROM combined_analysis_table
GROUP BY province_name,town_name
)
SELECT
combined_analysis_table.province_name,
combined_analysis_table.town_name,
ROUND((SUM(CASE WHEN type_of_water_source = 'river'
THEN number_of_people_served ELSE 0 END) * 100.0 / town_totals.total_ppl_serv), 0) AS river,
ROUND((SUM(CASE WHEN type_of_water_source = 'shared_tap'
THEN number_of_people_served ELSE 0 END) * 100.0 / town_totals.total_ppl_serv), 0) AS shared_tap,
ROUND((SUM(CASE WHEN type_of_water_source = 'tap_in_home'
THEN number_of_people_served ELSE 0 END) * 100.0 / town_totals.total_ppl_serv), 0) AS tap_in_home,
ROUND((SUM(CASE WHEN type_of_water_source = 'tap_in_home_broken'
THEN number_of_people_served ELSE 0 END) * 100.0 / town_totals.total_ppl_serv), 0) AS tap_in_home_broken,
ROUND((SUM(CASE WHEN type_of_water_source = 'well'
THEN number_of_people_served ELSE 0 END) * 100.0 / town_totals.total_ppl_serv), 0) AS well
FROM
combined_analysis_table
-- Since the town names are not unique, we have to join on a composite key. We group by province first, then by town.
JOIN 
town_totals  ON combined_analysis_table.province_name = town_totals.province_name AND combined_analysis_table.town_name = town_totals.town_name
GROUP BY 
combined_analysis_table.province_name,
combined_analysis_table.town_name
ORDER BY
combined_analysis_table.town_name;

-- looking up the town_aggregated_water_access temporay table
select *
from town_aggregated_water_access;
 
 -- town with the highest ratio of people who have taps, but have no running water?
    SELECT
province_name,
town_name,
ROUND(tap_in_home_broken / (tap_in_home_broken + tap_in_home) *

100,0) AS Pct_broken_taps

FROM
town_aggregated_water_access ;



/*This query creates the Project_progress table:*/
 CREATE TABLE Project_progress (
Project_id SERIAL PRIMARY KEY,
source_id VARCHAR(20) NOT NULL REFERENCES water_source(source_id) ON DELETE CASCADE ON UPDATE CASCADE,
Address VARCHAR(50),
Town VARCHAR(30),
Province VARCHAR(30),
Source_type VARCHAR(50),
Improvement VARCHAR(50),
Source_status VARCHAR(50) DEFAULT 'Backlog' CHECK (Source_status IN ('Backlog', 'In progress', 'Complete')),
Date_of_completion DATE,
Comments TEXT
);


/*FETCHING EVERYTHING FOR THE Project_progress_query*/
INSERT INTO project_progress(Address,Town,Province,source_id,Source_type,Improvement)
SELECT
location.address,
location.town_name,
location.province_name,
water_source.source_id,
water_source.type_of_water_source,
CASE WHEN results = "Contaminated: Chemical"
THEN "Install RO Filter" 
 WHEN results = "Contaminated: Biological"
THEN "Install UV and RO Filter" 
WHEN type_of_water_source = "river"
THEN "drill well"
WHEN type_of_water_source = "shared_tap" AND time_in_queue >=30
THEN CONCAT("Install ", FLOOR(time_in_queue / 30), " taps nearby")
WHEN type_of_water_source = "tap_in_home_broken"
THEN "Diagnose local infrastructure" ELSE NULL END AS Improvent
FROM
water_source
LEFT JOIN
well_pollution ON water_source.source_id = well_pollution.source_id
INNER JOIN
visits ON water_source.source_id = visits.source_id
INNER JOIN
location ON location.location_id = visits.location_id
WHERE
visits.visit_count = 1 
AND ( (well_pollution.results != 'Clean')
OR water_source.type_of_water_source  IN ('tap_in_home_broken','river')
OR (water_source.type_of_water_source = 'shared_tap' AND visits.time_in_queue >= 30));

-- looking up our project progress table
select *
from project_progress;


    
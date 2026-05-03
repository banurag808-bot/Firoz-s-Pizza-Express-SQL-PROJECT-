select * from customer_orders;
select * from pizza_ingredients;
select * from pizza_names;
select * from pizza_recipes;
select * from runner_orders;
select * from runners;
set search_path to schema_name , firozs_pizza_express;
----------------------------------------------------------------------------------------------------------------
-- 1. How many runners signed up each week? (Assume week starts Monday.)

select date_trunc('week',pickup_time) as weeks,count(runner_id) as total_runners
from runner_orders
group by weeks
having date_trunc('week',pickup_time) is not null
order by weeks

------------------------------------------------------------------------------------------------------------------
-- 2. What's the average time (in minutes) between runner registration and their first pickup?

WITH first_pickup AS (SELECT ro.runner_id,MIN(ro.pickup_time) AS first_pickup_time
FROM runner_orders ro
WHERE ro.pickup_time IS NOT NULL
GROUP BY ro.runner_id)
SELECT AVG(EXTRACT(EPOCH FROM (fp.first_pickup_time - r.registration_date)) / 60) AS avg_minutes
FROM runners r
JOIN first_pickup fp 
ON r.runner_id = fp.runner_id;
---------------------------------------------------------------------------------------------------------------------
-- 3. What’s the successful delivery count per runner?

select runner_id,count(*) as total_successful_delivery from runner_orders
where pickup_time is not null
group by runner_id
order by runner_id

--------------------------------------------------------------------------------------------------------------------
-- 4. Delivery success rate per runner (ratio of non-cancelled to total assigned orders)?

with cte as(select runner_id, count(order_id) as tol from runner_orders where pickup_time is not null group by runner_id),
me as (select runner_id,count(order_id)as total from runner_orders group by runner_id)
select runner_id,concat((tol*100/total),'%') as success_rate_per_runner
from cte 
join me using(runner_id)
order by runner_id

--------------------------------------------------------------------------------------------------------------------
-- 5. Average speed per runner (distance/duration); any noticeable trends?

with cte as (select runner_id,sum(distance_km)as tol from runner_orders group by runner_id),
time as (select runner_id,round(sum(duration_mins)::numeric/60,2) as total from runner_orders group by runner_id)
select runner_id,round((tol/total),2)as average_speed_per_runner from cte
join time using(runner_id)

----------------------------------------------------------------------------------------------------------------------------
-- B. Order & Delivery Insights
-- 1. Total number of pizzas ordered

select count(pizza_id) as total_number_of_pizza_orders from 
customer_orders

-------------------------------------------------------------------------------------------------------------------
-- 2. Unique customer orders count.

select customer_id,count(distinct order_id) as order_count from customer_orders
group by customer_id
order by customer_id

-------------------------------------------------------------------------------------------------------------------
-- 3. Average waiting time (order_time to pickup_time) for successful deliveries.

select round(avg(extract(EPOCH from (ro.pickup_time-c.order_time)/60)),1) as average_waiting_time from customer_orders c
join runner_orders ro using(order_id)
where ro.pickup_time is not null

--------------------------------------------------------------------------------------------------------------
-- 4. Difference between longest and shortest delivery durations.

select max(duration_mins) as longest_delivery_duration,min(duration_mins) as shortest_delivery_duration
from runner_orders

-----------------------------------------------------------------------------------------------------------------
-- C. Ingredient Optimization
-- 1. List standard ingredients per pizza (by name).

select p.pizza_name,string_agg(pi.ingredient_name,',') as standard_ingredients from pizza_names p
join pizza_recipes pr using(pizza_id)
join pizza_ingredients pi using(ingredient_id)
group by p.pizza_name

-------------------------------------------------------------------------------------------------------------------
-- 2. Most commonly added extra ingredient (name).

with cte as(select unnest(string_to_array(c.extras, ',')) as ingredient from customer_orders c
where c.extras <> '')
select pi.ingredient_name,count(*) as total
from cte ct
join pizza_ingredients pi on ct.ingredient::int = pi.ingredient_id
group by pi.ingredient_name
order by total desc

-------------------------------------------------------------------------------------------------------------------
-- 3. Most commonly excluded ingredient.

select pi.ingredient_name,count(c.exclusions) from customer_orders c
join pizza_ingredients pi on pi.ingredient_id = c.exclusions::int
where c.exclusions <> ''
group by pi.ingredient_name
-------------------------------------------------------------------------------------------------------------------
-- 4. Total count of each ingredient used in delivered pizzas, sorted descending

WITH base_ingredients AS (
SELECT c.order_id,pi.ingredient_id FROM customer_orders c
JOIN pizza_recipes pr ON c.pizza_id = pr.pizza_id
JOIN pizza_ingredients pi ON pr.ingredient_id = pi.ingredient_id),

extras AS (SELECT c.order_id,UNNEST(STRING_TO_ARRAY(c.extras, ','))::INT AS ingredient_id 
FROM customer_orders c
WHERE c.extras IS NOT NULL AND c.extras <> ''),

exclusions AS (SELECT c.order_id,UNNEST(STRING_TO_ARRAY(c.exclusions, ','))::INT AS ingredient_id 
FROM customer_orders c
WHERE c.exclusions IS NOT NULL AND c.exclusions <> ''),

final_ingredients AS (SELECT * FROM base_ingredients
UNION ALL
SELECT * FROM extras
EXCEPT
SELECT * FROM exclusions)

SELECT fi.ingredient_id,COUNT(*) AS total FROM final_ingredients fi
JOIN runner_orders ro ON fi.order_id = ro.order_id
WHERE ro.pickup_time IS NOT NULL
GROUP BY fi.ingredient_id
ORDER BY total DESC;
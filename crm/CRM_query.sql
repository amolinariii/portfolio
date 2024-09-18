/*Objectives:
1. How is each sales team performing compared to the rest?

2. What products and series are doing the best and worst?

3. Which accounts and sectors are most favorable?
*/

-- a. Initiate database and use it. Upload csv data to database using tasks. ---------------------------------------------------------------------------
CREATE DATABASE 
	CRM_OPPURTUNITIES;
USE 
	CRM_OPPURTUNITIES;

-- b. Table Processing and Cleaning --------------------------------------------------------------------------------------------------------------------

-- 1.a accounts table exploration
SELECT 
	TOP 10 * 
FROM 
	dbo.accounts; -- returns columns and preview of values

SELECT 
	COLUMN_NAME, DATA_TYPE -- returns column data type
FROM 
	INFORMATION_SCHEMA.COLUMNS
WHERE 
	TABLE_NAME = 'accounts';
-- Columns (year_established, revenue, employees) are type varchar, need to convert to double and int for later computations

-- 1.b Change data types of year_established, revenue, and employees in the 'accounts' table.
ALTER TABLE 
	dbo.accounts 
ALTER COLUMN 
	year_established INT;

ALTER TABLE 
	dbo.accounts 
ALTER COLUMN 
	revenue NUMERIC(7,2);

ALTER TABLE 
	dbo.accounts 
ALTER COLUMN
	employees INT;

-- 2.a products table exploration
SELECT 
	* 
FROM 
	dbo.products; -- returns columns and preview of values


SELECT 
	COLUMN_NAME, DATA_TYPE -- returns column data type
FROM 
	INFORMATION_SCHEMA.COLUMNS
WHERE 
	TABLE_NAME = 'products';
-- All column data types are fine as is.

-- 3.a sales_pipeline table exploration
SELECT 
	TOP 10 * 
FROM 
	dbo.sales_pipeline; -- returns columns and preview of values

SELECT 
	TOP 10 * 
FROM 
	dbo.sales_pipeline 
WHERE 
	account IS NULL;
-- Account column has null values which should not exist. Set null values to "New Prospect"
-- Close_value has null values as well. New column named "Potential Sale" to identify potential sales value and missed sales.
-- Close_value column has nulls. Change to zero for computations.
-- Product column has "GTXPro" instead of "GTX Pro", this issue must be fixed to join table values.
-- Set prices from products table to new "Potential Sale' column.


SELECT 
	COLUMN_NAME, DATA_TYPE -- returns column data type
FROM 
	INFORMATION_SCHEMA.COLUMNS
WHERE 
	TABLE_NAME = 'sales_pipeline';
-- All column data types are fine as is.

--3.b Account column nulls changed 
UPDATE 
	dbo.sales_pipeline
SET 
	account = 'New Prospect'
WHERE 
	account IS NULL

--3.c Closed_values column nulls changed 
UPDATE 
	dbo.sales_pipeline
SET 
	close_value = 0
WHERE 
	close_value IS NULL;

--3.d Product column "GTXPro" value changed.
UPDATE 
	dbo.sales_pipeline
SET 
	product = 'GTX Pro'
WHERE 
	product = 'GTXPro';

--3.e Add new column "Potential Sale".
ALTER TABLE 
	dbo.sales_pipeline
ADD 
	potential_sale SMALLINT;

--3.f Set values for potential sales column from products table.
UPDATE 
	dbo.sales_pipeline
SET 
	sales_pipeline.potential_sale = products.sales_price
FROM 
	sales_pipeline
JOIN 
	products ON sales_pipeline.product = products.product;

-- 4.a Sales teams table exploration
SELECT 
	* 
FROM 
	dbo.sales_teams; -- returns columns and preview of values

SELECT 
	COLUMN_NAME, DATA_TYPE -- returns column data type
FROM 
	INFORMATION_SCHEMA.COLUMNS
WHERE 
	TABLE_NAME = 'sales_teams';
-- All column data types are fine as is.

-- 5.a Joining accounts, products, sales_pipeline, and sales_teams to create a master table.

SELECT 
    sp.opportunity_id, 
    sp.sales_agent, 
    sp.product, 
    sp.account, 
    sp.deal_stage, 
    sp.engage_date, 
    sp.close_date, 
    sp.close_value, 
    sp.potential_sale, 
    a.sector,
    p.series, 
    st.manager, 
    st.regional_office
INTO 
	master_table
FROM 
    sales_pipeline sp 
LEFT JOIN 
    accounts a ON sp.account = a.account
JOIN 
    products p ON sp.product = p.product
JOIN 
    sales_teams st ON sp.sales_agent = st.sales_agent;

-- Need to fill in nulls for sector column to complete master_table.
UPDATE 
	dbo.master_table
SET 
	sector = 'unknown'
WHERE 
	sector IS NULL;

-- Confirm table is complete
SELECT 
	TOP 10 * 
FROM 
	dbo.master_table;

-- All tables have been cleaned and are ready for analysis.



-- Objective 1: How is each sales team performing compared to the rest? ----------------------------------------------------------------

-- Overall Sales by regions based on if deals were closed
SELECT
	regional_office, 
	sum(close_value) sales_generated
FROM
	dbo.master_table
WHERE
	deal_stage = 'Won'
group by
	regional_office
order by
	sales_generated desc;

-- Overall Sales by managers if deals were closed.
SELECT
	manager, 
	regional_office,
	sum(close_value) sales_generated
FROM
	dbo.master_table
WHERE
	deal_stage = 'Won'
group by
	manager, regional_office
order by
	sales_generated desc;

-- Overall Sales by sales agents based on if deals were closed
SELECT
	sales_agent,
	manager, 
	regional_office,
	sum(close_value) won_sales_generated
INTO
	sales_1
FROM
	dbo.master_table
WHERE
	deal_stage = 'Won'
group by
	sales_agent, manager, regional_office
order by
	won_sales_generated desc;

-- Overall Sales by regions based on if deals were closed
SELECT
	regional_office, 
	sum(potential_sale) lost_sales
FROM
	dbo.master_table
WHERE
	deal_stage = 'Lost'
group by
	regional_office
order by
	lost_sales asc;

-- Overall Sales by managers if deals were closed.
SELECT
	manager, 
	regional_office,
	sum(potential_sale) sales_generated
FROM
	dbo.master_table
WHERE
	deal_stage = 'Lost'
group by
	manager, regional_office
order by
	sales_generated asc;

-- Overall Sales by sales agents based on if deals were lost.
SELECT
	sales_agent,
	manager, 
	regional_office,
	sum(potential_sale) lost_sales
INTO
	sales_2
FROM
	dbo.master_table
WHERE
	deal_stage = 'Lost'
group by
	sales_agent, manager, regional_office
order by
	lost_sales asc;

-- Win to lost ratio of overall sales.
WITH temp AS
( -- CTE needed for win_ratio combination.
    SELECT
        mt.sales_agent,
        mt.manager,
        mt.regional_office,
        (SELECT 
			CAST(SUM(potential_sale) AS NUMERIC(10,0))
         FROM 
			dbo.master_table 
         WHERE 
			deal_stage = 'Won' AND sales_agent = mt.sales_agent) AS sales_generated,
        (SELECT 
			CAST(SUM(potential_sale) AS NUMERIC(10,0))
         FROM 
			dbo.master_table 
         WHERE 
			deal_stage = 'Lost' AND sales_agent = mt.sales_agent) AS sales_missed
    FROM 
        dbo.master_table mt
)
SELECT 
	*, 
	ROUND((sales_generated/sales_missed),2) win_ratio
INTO
	sales_3
FROM 
	temp
GROUP BY
	sales_agent,
	manager,
	regional_office,
	sales_generated,
	sales_missed
ORDER BY
	win_ratio DESC;

-- Potential Sales by agent
SELECT
	sales_agent,
	manager,
	regional_office,
	sum(potential_sale) potential_sales
INTO
	sales_4
FROM
	master_table
WHERE
	deal_stage != 'Won' OR deal_stage != 'Lost'
GROUP BY
	sales_agent,
	manager,
	regional_office
ORDER BY 
	potential_sales DESC;

-- Sales sold above target price by agent
SELECT
	sales_agent,
	manager,
	regional_office,
	COUNT((close_value - potential_sale)) orders_above_price,
	SUM((close_value - potential_sale)) sales_above_price
INTO
	sales_5
FROM
	master_table 
WHERE
	(close_value - potential_sale) > 0
GROUP BY 
	sales_agent,
	manager,
	regional_office
ORDER BY
	sales_above_price DESC;

-- Sales sold below target price by agent
SELECT 
	sales_agent,
	manager,
	regional_office,
	COUNT((close_value - potential_sale)) orders_below_price,
	SUM((close_value - potential_sale)) sales_below_price
INTO
	sales_6
FROM
	master_table
WHERE
	(close_value - potential_sale) < 0
GROUP BY 
	sales_agent,
	manager,
	regional_office
ORDER BY
	sales_below_price DESC;

-- Finalized sales performance table.
SELECT
	s1.sales_agent,
	s1.manager,
	s1.regional_office,
	s1.won_sales_generated,
	s2.lost_sales,
	s3.win_ratio,
	s4.potential_sales,
	s5.sales_above_price,
	s5.orders_above_price,
	s6.sales_below_price,
	s6.orders_below_price
INTO
	sales_performance
FROM
	sales_1 s1
JOIN sales_2 s2 ON s1.sales_agent = s2.sales_agent
JOIN sales_3 s3 ON s2.sales_agent = s3.sales_agent
JOIN sales_4 s4 ON s3.sales_agent = s4.sales_agent
JOIN sales_5 s5 ON s4.sales_agent = s5.sales_agent
JOIN sales_6 s6 ON s5.sales_agent = s6.sales_agent

SELECT 
	* 
FROM 
	sales_performance


-- Objective 2: What products are doing the best and worst? ---------------------------------------------------------------------------------------
SELECT 
	TOP 10 * 
FROM 
	dbo.master_table;

-- Products by won closed deals.
SELECT
	product,
	series,
	SUM(close_value) sales,
	COUNT(product) orders,
	min(close_value) min_product_price,
	max(close_value) max_product_price,
	potential_sale product_price,
	(SUM(close_value)/COUNT(product)) avg_price,
	(SUM(close_value)/COUNT(product) - potential_sale) variance
INTO 
	product1
FROM
	dbo.master_table
WHERE
	deal_stage = 'Won'
GROUP BY
	product,
	series,
	potential_sale
ORDER BY 
	sales DESC;

-- Products by lost deals
SELECT
	product,
	series,
	COUNT(product) orders_missed
INTO 
	product2
FROM
	dbo.master_table
WHERE
	deal_stage = 'Lost'
GROUP BY
	product,
	series
ORDER BY 
	orders_missed DESC;

-- Products by potential sales and prospects
SELECT
	product,
	series,
	sum(potential_sale) potential_sales,
	count(product) potential_orders
INTO
	product3
FROM
	dbo.master_table
WHERE
	deal_stage != 'Won' OR deal_stage != 'Lost'
GROUP BY
	product,
	series
ORDER BY
	potential_orders

-- Product Performance
SELECT
	p1.product,
	p1.series,
	p1.sales,
	p1.orders,
	p1.min_product_price,
	p1.max_product_price,
	p1.avg_price,
	p1.product_price,
	p1.variance,
	p2.orders_missed,
	p3.potential_sales,
	p3.potential_orders,
	ROUND((CAST(p1.orders AS NUMERIC(5,2))/CAST(p2.orders_missed AS NUMERIC(5,2))),2) win_ratio
INTO
	product_performance
FROM 
	product1 p1
JOIN product2 p2 ON p1.product = p2.product
JOIN product3 p3 ON p2.product = p3.product;

SELECT  
	* 
FROM 
	product_performance;


-- Objective 3: Which accounts and sectors are most favorable? ----------------------------------------------------------------------------------


-- Account summary by won deals
SELECT  
	account,
	product,
	sector,
	count(close_value) orders,
	sum(close_value) sales,
	AVG(close_value) avg_price,
	potential_sale product_price,
	(AVG(close_value) - potential_sale) variance
INTO
	account1
FROM 
	master_table
WHERE 
	deal_stage = 'Won'
GROUP BY
	account,
	product,
	sector,
	potential_sale
ORDER BY
	account, sales DESC;


-- Account summary by lost deals
SELECT  
	account,
	product,
	sector,
	count(close_value) missed_orders,
	sum(potential_sale) missed_sales
INTO
	account2
FROM 
	master_table
WHERE 
	deal_stage = 'Lost'
GROUP BY
	account,
	product,
	sector
ORDER BY
	account, missed_sales DESC;

-- Account summary by prospective sales
SELECT  
	account,
	product,
	sector,
	count(close_value) potential_orders,
	sum(potential_sale) potential_sales
INTO
	account3
FROM 
	master_table
WHERE 
	deal_stage != 'Won' OR deal_stage != 'Lost'
GROUP BY
	account,
	product,
	sector
ORDER BY
	account, potential_sales DESC;

SELECT
	a1.account,
	a1.product,
	a1.sector,
	a1.orders,
	a1.sales,
	a1.avg_price,
	a1.product_price,
	a1.variance,
	a3.potential_orders,
	a3.potential_sales
INTO
	account4
FROM
	account1 a1
RIGHT JOIN account3 a3 ON a1.account = a3.account AND a1.product = a3.product;

SELECT
	a4.account,
	a4.product,
	a4.sector,
	a4.orders,
	a4.sales,
	a4.avg_price,
	a4.product_price,
	a4.variance,
	a2.missed_orders,
	a2.missed_sales,
	a4.potential_orders,
	a4.potential_sales
INTO
	account_performance
FROM
	account4 a4
LEFT JOIN account2 a2 ON a4.account = a2.account AND a4.product = a2.product;


SELECT * FROM account_performance
DROP TABLE account_performance;
DROP TABLE account1;
DROP TABLE account2;
DROP TABLE account3;
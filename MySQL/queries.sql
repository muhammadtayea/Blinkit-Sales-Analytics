SELECT * FROM sales_raw LIMIT 10;

SELECT COUNT(*) FROM sales_raw;

DESCRIBE sales_raw;
SHOW COLUMNS FROM sales_raw;

-- ======================================
-- Create the new table:  sales_cleaned
-- ======================================

CREATE TABLE sales_cleaned AS
SELECT *
FROM sales_raw;

SELECT * FROM sales_cleaned LIMIT 10;

SELECT COUNT(*) FROM sales_cleaned;

DESCRIBE sales_cleaned;

-- ======================================
-- Change the column names
-- ======================================

ALTER TABLE sales_cleaned
RENAME COLUMN `Item Fat Content` TO item_fat_content,

RENAME COLUMN `Item Identifier` TO item_id,

RENAME COLUMN `Item Type` TO item_type,

RENAME COLUMN `Outlet Establishment Year` TO outlet_year,

RENAME COLUMN `Outlet Identifier` TO outlet_id,

RENAME COLUMN `Outlet Location Type` TO outlet_location,

RENAME COLUMN `Outlet Size` TO outlet_size,

RENAME COLUMN `Outlet Type` TO outlet_type,

RENAME COLUMN `Item Visibility` TO item_visibility,

RENAME COLUMN `Item Weight` TO item_weight,

RENAME COLUMN `Sales` TO revenue,

RENAME COLUMN `Rating` TO rating;

-- ======================================
-- Fix inconsistent categorical values 
-- ======================================
-- ========================
-- 1. Unique values per column
-- ========================
SELECT DISTINCT Item_Fat_Content FROM sales_cleaned;

SELECT DISTINCT Item_Type FROM sales_cleaned;

SELECT DISTINCT Outlet_Type FROM sales_cleaned;

SELECT DISTINCT Outlet_Location FROM sales_cleaned;

SELECT DISTINCT Outlet_Size FROM sales_cleaned;

SELECT DISTINCT Outlet_Type FROM sales_cleaned;

-- Fix: item_fat_content

UPDATE sales_cleaned
SET item_fat_content = 'Low Fat'
WHERE item_fat_content IN ('LF', 'low fat');

UPDATE sales_cleaned
SET item_fat_content = 'Regular'
WHERE item_fat_content IN ('reg');

-- ========================
-- 2. Trim spaces ( hidden killer )
-- ========================
UPDATE sales_cleaned
SET 
    item_fat_content = TRIM(item_fat_content),

    item_type = TRIM(item_type),

    outlet_location = TRIM(outlet_location),

    outlet_size = TRIM(outlet_size),

    outlet_type = TRIM(outlet_type);

-- ======================================
-- Handle NULL values     
-- ======================================

SELECT 
    SUM(item_weight IS NULL) AS missing_weight,
    SUM(outlet_size IS NULL) AS missing_outlet_size
FROM sales_cleaned;

UPDATE sales_cleaned s
JOIN (
    SELECT item_type, AVG(item_weight) AS avg_weight
    FROM sales_cleaned
    WHERE item_weight IS NOT NULL
    GROUP BY item_type
) t
ON s.item_type = t.item_type
SET s.item_weight = t.avg_weight
WHERE s.item_weight IS NULL;

-- ======================================
-- Fix impossible values (suspicious values)
-- ======================================
-- ========================
-- 1. Item Visibility = 0      (very common issue)
-- ========================
SELECT COUNT(*) FROM sales_cleaned WHERE item_visibility = 0;      -- 526 rows

UPDATE sales_cleaned
SET item_visibility = NULL
WHERE item_visibility = 0;

-- Then fill:

UPDATE sales_cleaned s
JOIN (
    SELECT item_type, AVG(item_visibility) AS avg_vis
    FROM sales_cleaned
    WHERE item_visibility IS NOT NULL
    GROUP BY item_type
) t
ON s.item_type = t.item_type
SET s.item_visibility = t.avg_vis
WHERE s.item_visibility IS NULL;

-- ========================
-- 2. Negative or zero revenue ( if any )
-- ========================
SELECT * FROM sales_cleaned WHERE revenue <= 0;   -- not exists

-- ======================================
-- Remove duplicates                              -- not exists
-- ======================================

SELECT item_id, outlet_id, COUNT(*)
FROM sales_cleaned
GROUP BY item_id, outlet_id
HAVING COUNT(*) > 1;

-- ======================================
-- Data Exploration
-- ======================================
-- ========================
-- 1. Create Analysis Table 
-- ========================
CREATE TABLE sales_analysis AS
SELECT *
FROM sales_cleaned;

-- ========================
-- 2. Basic statistics 
-- ========================
SELECT 
    COUNT(*) AS total_rows,
    ROUND(AVG(revenue),2) AS avg_revenue,
    MIN(revenue) AS min_revenue,
    MAX(revenue) AS max_revenue
FROM sales_analysis;

SELECT 
    COUNT(*) AS total_rows,
    ROUND(AVG(item_weight), 2) AS avg_item_weight,
    MIN(item_weight) AS min_item_weight,
    MAX(item_weight) AS max_item_weight
FROM sales_analysis;

SELECT 
    COUNT(*) AS total_rows,
    ROUND(AVG(rating),2) AS avg_Rating,
    MIN(rating) AS min_rating,
    MAX(rating) AS max_rating
FROM sales_analysis;

SELECT 
    COUNT(*) AS total_rows,
    ROUND(AVG(item_visibility),2) AS avg_item_visibility,
    MIN(item_visibility) AS min_item_visibility,
    MAX(item_visibility) AS max_item_visibility
FROM sales_analysis;

-- ========================
-- 3. Business-level exploration 
-- ========================
-- 1. Total sales
SELECT ROUND(SUM(revenue), 2) AS total_revenue
FROM sales_analysis;

-- ========================
-- 2. Sales by Item Type
SELECT 
    item_type,
    ROUND(SUM(revenue), 2) AS revenue
FROM sales_analysis
GROUP BY item_type
ORDER BY revenue DESC;

-- ========================
-- 3. Sales by Outlet Type
SELECT 
    outlet_type,
    ROUND(SUM(revenue), 2) AS revenue
FROM sales_analysis
GROUP BY outlet_type
ORDER BY revenue DESC;

-- ========================
-- 4. Sales by Fat Content
SELECT 
    item_fat_content,
    ROUND(SUM(revenue), 2) AS revenue
FROM sales_analysis
GROUP BY item_fat_content
ORDER BY revenue DESC;

-- ========================
-- 5. sales by Store Age ( Establishment Year )
SELECT 
    outlet_year,
    ROUND(SUM(revenue), 2) AS revenue
FROM sales_analysis
GROUP BY outlet_year
ORDER BY outlet_year;

-- ======================================
-- 4. Relationships
-- ======================================
-- ========================
-- 1. Does visibility affect sales ?
SELECT 
    Visibility_level,
    ROUND(AVG(total_revenue), 2) AS avg_sales
FROM (
    SELECT 
        outlet_id,
        CASE 
            WHEN item_visibility < 0.03 THEN 'Low'
            WHEN item_visibility < 0.07 THEN 'Medium'
            ELSE 'High'
        END AS Visibility_level,
        SUM(revenue) AS total_revenue
    FROM sales_analysis
    GROUP BY outlet_id, Visibility_level
) t
GROUP BY Visibility_level;

-- ========================
-- 2. Does rating affect sales ?
SELECT 
    rating,
    ROUND(AVG(revenue), 2) AS avg_sales
FROM sales_analysis
GROUP BY rating
ORDER BY rating;

-- =====================================
-- Important analysis questions 
-- =====================================
-- ========================
-- 1. Are top categories (item_type) actually efficient ?
SELECT 
    item_type,
    COUNT(*) AS item_count,
    ROUND(SUM(revenue), 2) AS revenue,
    ROUND(AVG(revenue), 2) AS avg_sales_per_item
FROM sales_analysis
GROUP BY item_type
ORDER BY revenue DESC;

-- ========================
-- 2. Outlet performance is misleading — fix it.
SELECT 
    outlet_type,
    COUNT(*) AS items,
    ROUND(SUM(revenue),2) AS revenue,
    ROUND(AVG(revenue),2) AS avg_sales
FROM sales_analysis
GROUP BY outlet_type;

-- ========================
-- 3. Fat content — business insight or garbage data ?
SELECT 
    item_fat_content,
    COUNT(*) AS items,
    ROUND(SUM(revenue), 2) AS revenue
FROM sales_analysis
GROUP BY item_fat_content;

-- ========================
-- 4. Does location impact sales ? 
SELECT 
    outlet_location,
	COUNT(*) AS items,
    ROUND(AVG(revenue), 2) AS avg_sales
FROM sales_analysis
GROUP BY outlet_location
ORDER BY avg_sales DESC;

-- ========================
-- 5. Are Store Age (Establishment Year) affect revenue ?
SELECT 
    outlet_year,
    COUNT(*) AS items,
    ROUND(AVG(revenue), 2) AS avg_sales
FROM sales_analysis
GROUP BY outlet_year
ORDER BY outlet_year;

-- ========================
-- =====================================
-- Interaction effects: Outlet Age + Location + Type
-- =====================================
-- ========================
-- 1: Combine Outlet Type + Location
SELECT 
    outlet_type,
    outlet_location,
    COUNT(*) AS products,
    ROUND(AVG(revenue), 2) AS avg_sales,
    ROUND(SUM(revenue), 2) AS total_revenue
FROM sales_analysis
GROUP BY outlet_type, outlet_location
ORDER BY avg_sales DESC;

-- ========================
-- 2: Add Outlet Age Layer
SELECT 
    outlet_type,
    outlet_location,
    outlet_year,
    ROUND(AVG(revenue), 2) AS avg_sales
FROM sales_analysis
GROUP BY outlet_type, outlet_location, outlet_year
ORDER BY avg_sales DESC;

select * from sales_analysis limit 20;
-- ========================
-- الحمد لله
-- Retail Inventory Management SQL Queries
-- Author: Deepanraj A - Data Analyst
-- Database: MySQL/PostgreSQL Compatible

-- ================================================
-- 1. INVENTORY OVERVIEW QUERIES
-- ================================================

-- Get current inventory levels by product
SELECT 
    p.product_id,
    p.product_name,
    p.category,
    i.quantity_on_hand,
    i.reorder_level,
    i.reorder_quantity,
    CASE 
        WHEN i.quantity_on_hand <= i.reorder_level THEN 'LOW STOCK'
        WHEN i.quantity_on_hand <= i.reorder_level * 1.5 THEN 'MODERATE'
        ELSE 'ADEQUATE'
    END AS stock_status
FROM products p
JOIN inventory i ON p.product_id = i.product_id
ORDER BY stock_status, quantity_on_hand;

-- ================================================
-- 2. LOW STOCK ALERT QUERY
-- ================================================

SELECT 
    p.product_name,
    p.category,
    s.supplier_name,
    i.quantity_on_hand,
    i.reorder_level,
    (i.reorder_level - i.quantity_on_hand) AS units_needed,
    p.unit_cost,
    (i.reorder_quantity * p.unit_cost) AS estimated_order_cost
FROM inventory i
JOIN products p ON i.product_id = p.product_id
JOIN suppliers s ON p.supplier_id = s.supplier_id
WHERE i.quantity_on_hand <= i.reorder_level
ORDER BY units_needed DESC;

-- ================================================
-- 3. INVENTORY TURNOVER ANALYSIS
-- ================================================

SELECT 
    p.product_name,
    p.category,
    SUM(s.quantity_sold) AS total_units_sold,
    AVG(i.quantity_on_hand) AS avg_inventory,
    CASE 
        WHEN AVG(i.quantity_on_hand) > 0 
        THEN ROUND(SUM(s.quantity_sold) / AVG(i.quantity_on_hand), 2)
        ELSE 0 
    END AS turnover_ratio,
    SUM(s.quantity_sold * p.unit_price) AS total_revenue
FROM products p
JOIN inventory i ON p.product_id = i.product_id
JOIN sales s ON p.product_id = s.product_id
WHERE s.sale_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
GROUP BY p.product_id, p.product_name, p.category
ORDER BY turnover_ratio DESC;

-- ================================================
-- 4. DEAD STOCK IDENTIFICATION
-- ================================================

SELECT 
    p.product_id,
    p.product_name,
    p.category,
    i.quantity_on_hand,
    i.last_stock_update,
    DATEDIFF(CURDATE(), i.last_stock_update) AS days_without_movement,
    (i.quantity_on_hand * p.unit_cost) AS tied_up_capital
FROM inventory i
JOIN products p ON i.product_id = p.product_id
LEFT JOIN sales s ON p.product_id = s.product_id 
    AND s.sale_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
WHERE s.sale_id IS NULL
    AND i.quantity_on_hand > 0
ORDER BY days_without_movement DESC, tied_up_capital DESC;

-- ================================================
-- 5. SALES TREND ANALYSIS
-- ================================================

SELECT 
    DATE_FORMAT(s.sale_date, '%Y-%m') AS month,
    p.category,
    COUNT(DISTINCT s.sale_id) AS transaction_count,
    SUM(s.quantity_sold) AS total_units_sold,
    SUM(s.quantity_sold * p.unit_price) AS total_revenue,
    AVG(s.quantity_sold * p.unit_price) AS avg_transaction_value
FROM sales s
JOIN products p ON s.product_id = p.product_id
WHERE s.sale_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
GROUP BY month, p.category
ORDER BY month DESC, total_revenue DESC;

-- ================================================
-- 6. STOCK VALUATION QUERY
-- ================================================

SELECT 
    p.category,
    COUNT(DISTINCT p.product_id) AS product_count,
    SUM(i.quantity_on_hand) AS total_units,
    SUM(i.quantity_on_hand * p.unit_cost) AS inventory_value_cost,
    SUM(i.quantity_on_hand * p.unit_price) AS inventory_value_retail,
    SUM((p.unit_price - p.unit_cost) * i.quantity_on_hand) AS potential_profit
FROM inventory i
JOIN products p ON i.product_id = p.product_id
GROUP BY p.category
ORDER BY inventory_value_cost DESC;

-- ================================================
-- 7. SUPPLIER PERFORMANCE ANALYSIS
-- ================================================

SELECT 
    s.supplier_name,
    s.contact_email,
    COUNT(DISTINCT p.product_id) AS products_supplied,
    SUM(i.quantity_on_hand) AS total_inventory_units,
    AVG(po.lead_time_days) AS avg_lead_time,
    AVG(po.order_accuracy_pct) AS avg_order_accuracy,
    SUM(po.order_total) AS total_purchase_value
FROM suppliers s
JOIN products p ON s.supplier_id = p.supplier_id
JOIN inventory i ON p.product_id = i.product_id
LEFT JOIN purchase_orders po ON s.supplier_id = po.supplier_id
    AND po.order_date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
GROUP BY s.supplier_id, s.supplier_name, s.contact_email
ORDER BY avg_order_accuracy DESC, avg_lead_time ASC;

-- ================================================
-- 8. REORDER RECOMMENDATIONS
-- ================================================

WITH sales_forecast AS (
    SELECT 
        product_id,
        AVG(daily_sales) AS avg_daily_sales,
        STDDEV(daily_sales) AS stddev_daily_sales
    FROM (
        SELECT 
            product_id,
            DATE(sale_date) AS sale_day,
            SUM(quantity_sold) AS daily_sales
        FROM sales
        WHERE sale_date >= DATE_SUB(CURDATE(), INTERVAL 60 DAY)
        GROUP BY product_id, sale_day
    ) daily_data
    GROUP BY product_id
)
SELECT 
    p.product_name,
    p.category,
    i.quantity_on_hand,
    ROUND(sf.avg_daily_sales, 2) AS avg_daily_sales,
    ROUND(i.quantity_on_hand / NULLIF(sf.avg_daily_sales, 0), 1) AS days_of_stock,
    CASE 
        WHEN i.quantity_on_hand / NULLIF(sf.avg_daily_sales, 0) <= 7 THEN 'URGENT'
        WHEN i.quantity_on_hand / NULLIF(sf.avg_daily_sales, 0) <= 14 THEN 'SOON'
        ELSE 'NOT NEEDED'
    END AS reorder_priority,
    ROUND(sf.avg_daily_sales * 30, 0) AS recommended_order_qty
FROM products p
JOIN inventory i ON p.product_id = i.product_id
JOIN sales_forecast sf ON p.product_id = sf.product_id
WHERE sf.avg_daily_sales > 0
ORDER BY days_of_stock ASC;

-- ================================================
-- 9. ABC ANALYSIS (Pareto Principle)
-- ================================================

WITH product_revenue AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.category,
        SUM(s.quantity_sold * p.unit_price) AS total_revenue
    FROM products p
    JOIN sales s ON p.product_id = s.product_id
    WHERE s.sale_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    GROUP BY p.product_id, p.product_name, p.category
),
revenue_with_cumulative AS (
    SELECT 
        *,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
        SUM(total_revenue) OVER () AS total_sum
    FROM product_revenue
)
SELECT 
    product_name,
    category,
    ROUND(total_revenue, 2) AS revenue,
    ROUND((cumulative_revenue / total_sum) * 100, 2) AS cumulative_percentage,
    CASE 
        WHEN (cumulative_revenue / total_sum) <= 0.80 THEN 'A - High Priority'
        WHEN (cumulative_revenue / total_sum) <= 0.95 THEN 'B - Medium Priority'
        ELSE 'C - Low Priority'
    END AS abc_classification
FROM revenue_with_cumulative
ORDER BY total_revenue DESC;

-- ================================================
-- 10. WAREHOUSE SPACE UTILIZATION
-- ================================================

SELECT 
    w.warehouse_name,
    w.location,
    COUNT(DISTINCT i.product_id) AS unique_products,
    SUM(i.quantity_on_hand) AS total_units,
    SUM(i.quantity_on_hand * p.unit_volume) AS total_volume_used,
    w.total_capacity_volume,
    ROUND((SUM(i.quantity_on_hand * p.unit_volume) / w.total_capacity_volume) * 100, 2) AS utilization_percentage
FROM warehouses w
JOIN inventory i ON w.warehouse_id = i.warehouse_id
JOIN products p ON i.product_id = p.product_id
GROUP BY w.warehouse_id, w.warehouse_name, w.location, w.total_capacity_volume
ORDER BY utilization_percentage DESC;

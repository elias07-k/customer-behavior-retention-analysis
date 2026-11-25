-- Customer Behavior & Retention Analysis
-- Dataset: UCI Online Retail (Online Retail.csv)
-- SQL dialect: SQLite
-- Table name: Online_Retail
--
-- Notes:
--   * InvoiceNo beginning with 'C' identifies a cancellation.
--   * CustomerID can be NULL for transactions without a customer identifier.
--   * Most sales/customer analyses exclude cancelled invoices and missing CustomerID.
--   * Revenue is Quantity * UnitPrice (dataset currency: GBP).

-- 1) Dataset overview / core KPIs
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoices_including_cancellations,
    COUNT(DISTINCT CustomerID) AS distinct_customers,
    SUM(Quantity * UnitPrice) AS net_revenue_including_cancellations
FROM Online_Retail;


-- 2) Average invoices per customer (excluding cancellations and missing CustomerID)
WITH customer_orders AS (
    SELECT
        CustomerID,
        COUNT(DISTINCT InvoiceNo) AS invoice_count
    FROM Online_Retail
    WHERE CustomerID IS NOT NULL
      AND InvoiceNo NOT LIKE 'C%'
    GROUP BY CustomerID
)
SELECT AVG(invoice_count) AS average_orders_per_customer
FROM customer_orders;


-- 3) Top 10 customers by revenue (excluding cancellations and missing CustomerID)
SELECT
    CustomerID,
    SUM(Quantity * UnitPrice) AS total_revenue,
    COUNT(DISTINCT InvoiceNo) AS total_orders
FROM Online_Retail
WHERE CustomerID IS NOT NULL
  AND InvoiceNo NOT LIKE 'C%'
GROUP BY CustomerID
ORDER BY total_revenue DESC
LIMIT 10;


-- 4) Revenue by country (excluding cancellations)
SELECT
    Country,
    SUM(Quantity * UnitPrice) AS total_revenue,
    COUNT(DISTINCT InvoiceNo) AS invoice_count,
    COUNT(DISTINCT CustomerID) AS customer_count
FROM Online_Retail
WHERE InvoiceNo NOT LIKE 'C%'
GROUP BY Country
ORDER BY total_revenue DESC;


-- 5) Top 10 products by quantity sold (exclude cancellations and non-positive quantities)
SELECT
    StockCode,
    Description,
    SUM(Quantity) AS total_quantity_sold,
    SUM(Quantity * UnitPrice) AS total_revenue
FROM Online_Retail
WHERE InvoiceNo NOT LIKE 'C%'
  AND Quantity > 0
GROUP BY StockCode, Description
ORDER BY total_quantity_sold DESC
LIMIT 10;


-- 6) Cancellation analysis (cancellation transaction value, shown as positive magnitude)
SELECT
    Country,
    COUNT(DISTINCT InvoiceNo) AS cancelled_invoices,
    SUM(ABS(Quantity * UnitPrice)) AS cancellation_value
FROM Online_Retail
WHERE InvoiceNo LIKE 'C%'
GROUP BY Country
ORDER BY cancellation_value DESC;


-- 7) Average basket size (items per completed invoice; exclude cancellations)
WITH invoice_baskets AS (
    SELECT
        InvoiceNo,
        SUM(Quantity) AS basket_quantity
    FROM Online_Retail
    WHERE InvoiceNo NOT LIKE 'C%'
    GROUP BY InvoiceNo
)
SELECT AVG(basket_quantity) AS average_items_per_invoice
FROM invoice_baskets;


-- 8) Repeat vs one-time customers (based on distinct completed invoices)
WITH customer_orders AS (
    SELECT
        CustomerID,
        COUNT(DISTINCT InvoiceNo) AS invoice_count
    FROM Online_Retail
    WHERE CustomerID IS NOT NULL
      AND InvoiceNo NOT LIKE 'C%'
    GROUP BY CustomerID
)
SELECT
    CASE
        WHEN invoice_count > 1 THEN 'Repeat Customer'
        ELSE 'One-Time Customer'
    END AS customer_type,
    COUNT(*) AS customer_count
FROM customer_orders
GROUP BY customer_type;


-- 9) Repeat customer rate (distinct customers with 2+ completed invoices / all identified customers)
WITH customer_orders AS (
    SELECT
        CustomerID,
        COUNT(DISTINCT InvoiceNo) AS invoice_count
    FROM Online_Retail
    WHERE CustomerID IS NOT NULL
      AND InvoiceNo NOT LIKE 'C%'
    GROUP BY CustomerID
)
SELECT
    COUNT(*) AS identified_customers,
    SUM(CASE WHEN invoice_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN invoice_count > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS repeat_customer_rate_pct
FROM customer_orders;


-- 10) Customer revenue segments (segment customers by completed-invoice revenue)
WITH customer_revenue AS (
    SELECT
        CustomerID,
        SUM(Quantity * UnitPrice) AS total_revenue
    FROM Online_Retail
    WHERE CustomerID IS NOT NULL
      AND InvoiceNo NOT LIKE 'C%'
    GROUP BY CustomerID
),
segmented_customers AS (
    SELECT
        CustomerID,
        total_revenue,
        CASE
            WHEN total_revenue >= 5000 THEN 'High Value'
            WHEN total_revenue >= 1000 THEN 'Medium Value'
            ELSE 'Low Value'
        END AS spending_segment
    FROM customer_revenue
)
SELECT
    spending_segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(total_revenue), 2) AS average_customer_revenue,
    ROUND(SUM(total_revenue), 2) AS segment_revenue
FROM segmented_customers
GROUP BY spending_segment
ORDER BY segment_revenue DESC;


-- 11) Monthly sales revenue trend (completed invoices only)
-- InvoiceDate is stored as text in the source CSV, often in M/D/YYYY H:MM format.
-- This query extracts the year and month for common M/D/YYYY or MM/DD/YYYY values.
WITH parsed_dates AS (
    SELECT
        InvoiceDate,
        Quantity,
        UnitPrice,
        CASE
            WHEN instr(InvoiceDate, '/') > 0 THEN
                substr(InvoiceDate, instr(InvoiceDate, '/') + 1,
                    instr(substr(InvoiceDate, instr(InvoiceDate, '/') + 1), '/') - 1)
            ELSE NULL
        END AS day_text,
        CASE
            WHEN instr(InvoiceDate, '/') > 0 THEN substr(InvoiceDate, 1, instr(InvoiceDate, '/') - 1)
            ELSE NULL
        END AS month_text,
        CASE
            WHEN instr(InvoiceDate, '/') > 0 THEN
                substr(InvoiceDate,
                    instr(InvoiceDate, '/') +
                    instr(substr(InvoiceDate, instr(InvoiceDate, '/') + 1), '/') + 1,
                    4)
            ELSE NULL
        END AS year_text
    FROM Online_Retail
    WHERE InvoiceNo NOT LIKE 'C%'
),
monthly_sales AS (
    SELECT
        printf('%04d-%02d', CAST(year_text AS INTEGER), CAST(month_text AS INTEGER)) AS sales_month,
        SUM(Quantity * UnitPrice) AS monthly_revenue
    FROM parsed_dates
    WHERE year_text IS NOT NULL
    GROUP BY sales_month
)
SELECT sales_month, monthly_revenue
FROM monthly_sales
ORDER BY sales_month;

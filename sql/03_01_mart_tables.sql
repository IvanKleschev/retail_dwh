--Создание Mart-витрин
CREATE SCHEMA IF NOT EXISTS mart;

--Ежедневные продажи
CREATE TABLE mart.daily_sales AS
SELECT
    d.date_value,
    COUNT(DISTINCT f.order_id) AS orders_count,
    SUM(f.price) AS revenue,
    SUM(f.freight_value) AS total_freight
FROM core.fct_order_items f
JOIN core.dim_date d ON f.order_date_sk = d.date_sk
WHERE f.order_status = 'delivered'
GROUP BY d.date_value;

--Продажи по категориям
CREATE TABLE mart.category_sales AS
SELECT
    p.product_category_english,
    DATE_TRUNC('month', d.date_value) AS month,
    SUM(f.price) AS revenue,
    COUNT(DISTINCT f.order_id) AS orders_count
FROM core.fct_order_items f
JOIN core.dim_product p ON f.product_sk = p.product_sk
JOIN core.dim_date d ON f.order_date_sk = d.date_sk
WHERE f.order_status = 'delivered'
GROUP BY p.product_category_english, DATE_TRUNC('month', d.date_value);

--RFM-сегментация клиентов
CREATE TABLE mart.customer_rfm AS
WITH rfm AS (
    SELECT
        c.customer_unique_id,
        MAX(d.date_value) AS last_order_date,
        COUNT(DISTINCT f.order_id) AS frequency,
        SUM(f.price) AS monetary
    FROM core.fct_order_items f
    JOIN core.dim_customer c ON f.customer_sk = c.customer_sk
    JOIN core.dim_date d ON f.order_date_sk = d.date_sk
    WHERE f.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    customer_unique_id,
    last_order_date,
    frequency,
    monetary,
    NTILE(4) OVER (ORDER BY last_order_date DESC) AS recency_score,
    NTILE(4) OVER (ORDER BY frequency) AS frequency_score,
    NTILE(4) OVER (ORDER BY monetary) AS monetary_score
FROM rfm;

select max(month), min(month)
from mart.category_sales;
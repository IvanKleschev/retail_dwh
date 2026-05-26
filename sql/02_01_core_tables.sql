--Создание схемы core
CREATE SCHEMA IF NOT EXISTS core;

--Измерение «Дата» 
-- Генерируем все даты от минимальной до максимальной в заказах
CREATE TABLE core.dim_date AS
SELECT
    TO_CHAR(dt, 'YYYYMMDD')::INT AS date_sk,
    dt AS date_value,
    EXTRACT(YEAR FROM dt) AS year,
    EXTRACT(MONTH FROM dt) AS month,
    EXTRACT(DAY FROM dt) AS day,
    TO_CHAR(dt, 'Day') AS day_of_week
FROM generate_series(
    (SELECT MIN(order_purchase_timestamp::DATE) FROM staging.raw_olist_orders),
    (SELECT MAX(order_purchase_timestamp::DATE) FROM staging.raw_olist_orders),
    '1 day'::interval
) AS dt;

--Измерение «Продавец»
CREATE TABLE core.dim_seller (
    seller_sk SERIAL PRIMARY KEY,
    seller_id VARCHAR(50) UNIQUE NOT NULL,
    seller_zip_code_prefix INT,
    seller_city VARCHAR(50),
    seller_state VARCHAR(50),
    effective_from TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    effective_to TIMESTAMP DEFAULT '9999-12-31 23:59:59',
    is_current BOOLEAN DEFAULT TRUE
);

--Заполняем продавцов
INSERT INTO core.dim_seller (seller_id, seller_zip_code_prefix, seller_city, seller_state)
SELECT seller_id, seller_zip_code_prefix, seller_city, seller_state
FROM staging.raw_olist_sellers;

--Измерение «Товар»
CREATE TABLE core.dim_product (
    product_sk SERIAL PRIMARY KEY,
    product_id VARCHAR(50) UNIQUE NOT NULL,
    product_category_name VARCHAR(50),
    product_category_english VARCHAR(50),
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
);

--Заполняем товары
INSERT INTO core.dim_product (product_id, product_category_name, product_category_english, product_weight_g, product_length_cm, product_height_cm, product_width_cm)
SELECT
    p.product_id,
    p.product_category_name,
    t.product_category_name_english,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM staging.raw_olist_products p
LEFT JOIN staging.raw_olist_product_category_translation t
    ON p.product_category_name = t.product_category_name;

--Измерение «Клиент» с SCD 2
CREATE TABLE core.dim_customer (
    customer_sk SERIAL PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix INT,
    customer_city VARCHAR(50),
    customer_state VARCHAR(50),
    effective_from TIMESTAMP NOT NULL,
    effective_to TIMESTAMP NOT NULL DEFAULT '9999-12-31 23:59:59',
    is_current BOOLEAN NOT NULL DEFAULT TRUE
);

/* заполняем адреса киентов, каждый клиент будет иметь одну запись (текущую) с городом, который встречается в его последнем заказе, если город менялся, создадим исторические версии с датами переезда */
-- Находим для каждого клиента все изменения города
WITH customer_city_changes AS (
    SELECT
        c.customer_id,
        c.customer_unique_id,
        c.customer_zip_code_prefix,
        c.customer_city,
        c.customer_state,
        MIN(o.order_purchase_timestamp::TIMESTAMP) AS first_order_with_city
    FROM staging.raw_olist_customers c
    JOIN staging.raw_olist_orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.customer_unique_id, c.customer_zip_code_prefix, c.customer_city, c.customer_state
    -- Это даст по одной строке на каждую уникальную комбинацию клиента и города
),
versioned AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY first_order_with_city) AS version_num,
        LEAD(first_order_with_city) OVER (PARTITION BY customer_id ORDER BY first_order_with_city) AS next_version_start
    FROM customer_city_changes
)
INSERT INTO core.dim_customer (customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state, effective_from, effective_to, is_current)
SELECT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    first_order_with_city AS effective_from,
    COALESCE(next_version_start - INTERVAL '1 second', '9999-12-31 23:59:59') AS effective_to,
    CASE WHEN next_version_start IS NULL THEN TRUE ELSE FALSE END AS is_current
FROM versioned;

--!!!ошибка у core.dim_date нет первичного ключа
ALTER TABLE core.dim_date ADD PRIMARY KEY (date_sk);

--Таблица фактов
CREATE TABLE core.fct_order_items (
    order_item_sk BIGSERIAL PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL,
    order_item_id INT NOT NULL,
    customer_sk INT REFERENCES core.dim_customer(customer_sk),
    product_sk INT REFERENCES core.dim_product(product_sk),
    seller_sk INT REFERENCES core.dim_seller(seller_sk),
    order_date_sk INT REFERENCES core.dim_date(date_sk),
    price NUMERIC(10,2),
    freight_value NUMERIC(10,2),
    order_status VARCHAR(20)
);

-- Заполняем факты
INSERT INTO core.fct_order_items (order_id, order_item_id, customer_sk, product_sk, seller_sk, order_date_sk, price, freight_value, order_status)
SELECT
    oi.order_id,
    oi.order_item_id,
    c.customer_sk,
    p.product_sk,
    s.seller_sk,
    d.date_sk,
    oi.price,
    oi.freight_value,
    o.order_status
FROM staging.raw_olist_order_items oi
JOIN staging.raw_olist_orders o ON oi.order_id = o.order_id
JOIN core.dim_customer c ON o.customer_id = c.customer_id
    AND o.order_purchase_timestamp::TIMESTAMP >= c.effective_from
    AND o.order_purchase_timestamp::TIMESTAMP < c.effective_to  -- строго меньше, чтобы не попасть в следующую версию
JOIN core.dim_product p ON oi.product_id = p.product_id
JOIN core.dim_seller s ON oi.seller_id = s.seller_id
JOIN core.dim_date d ON d.date_value = o.order_purchase_timestamp::DATE;


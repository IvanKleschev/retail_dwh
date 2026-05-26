-- Дубликаты в фактах по комбинации order_id + order_item_id
SELECT order_id, order_item_id, COUNT(*)
FROM core.fct_order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

-- Пропуски customer_sk
SELECT COUNT(*) AS missing_customers
FROM core.fct_order_items
WHERE customer_sk IS NULL;

-- Проверка SCD2: перекрытия периодов (как мы обсуждали ранее)
SELECT a.customer_id, a.customer_sk, a.effective_from, a.effective_to,
       b.customer_sk, b.effective_from, b.effective_to
FROM core.dim_customer a
JOIN core.dim_customer b ON a.customer_id = b.customer_id AND a.customer_sk <> b.customer_sk
WHERE a.effective_from < b.effective_to AND a.effective_to > b.effective_from;

--scd 2: поиск перекрытий периодов для одного клиента
SELECT 
    a.customer_id,
    a.customer_sk AS sk1,
    a.effective_from AS from1,
    a.effective_to AS to1,
    b.customer_sk AS sk2,
    b.effective_from AS from2,
    b.effective_to AS to2
FROM core.dim_customer a
JOIN core.dim_customer b 
    ON a.customer_id = b.customer_id 
    AND a.customer_sk <> b.customer_sk
WHERE a.effective_from < b.effective_to 
  AND a.effective_to > b.effective_from;

--scd 2: поиск временных пропусков между версиями
WITH ordered_versions AS (
    SELECT
        customer_id,
        customer_sk,
        effective_from,
        effective_to,
        LEAD(effective_from) OVER (PARTITION BY customer_id ORDER BY effective_from) AS next_from
    FROM core.dim_customer
)
SELECT
    customer_id,
    customer_sk,
    effective_from,
    effective_to,
    next_from
FROM ordered_versions
WHERE effective_to <> '9999-12-31 23:59:59'   -- не текущая версия
  AND next_from IS NOT NULL                     -- есть следующая версия
  AND effective_to <> next_from;                -- стыковка нарушена
  
  --scd 2: поиск дубликатов по дате начала версии
SELECT
    customer_id,
    effective_from,
    COUNT(*) AS cnt
FROM core.dim_customer
GROUP BY customer_id, effective_from
HAVING COUNT(*) > 1;

 --scd 2: поиск полностью идентичных периодов
SELECT
    customer_id,
    effective_from,
    effective_to,
    COUNT(*) AS cnt
FROM core.dim_customer
GROUP BY customer_id, effective_from, effective_to
HAVING COUNT(*) > 1;
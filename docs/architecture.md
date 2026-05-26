# Архитектура хранилища данных

Хранилище построено для анализа продаж интернет‑магазина на основе датасета Olist Brazilian E‑Commerce. Архитектура — трёхслойная (staging → core → mart) с использованием методологии Кимбалла (звезда).

## Слои

### Staging (схема `staging`)
- Содержит сырые данные, максимально приближенные к исходным CSV.
- Все поля импортируются как текст (`TEXT` / `VARCHAR`), чтобы избежать ошибок при загрузке.
- Таблицы: `raw_olist_customers`, `raw_olist_orders`, `raw_olist_order_items`, `raw_olist_products`, `raw_olist_sellers`, `raw_olist_product_category_translation`, `raw_olist_order_reviews`, `raw_olist_order_payments`, `raw_olist_geolocation`.

### Core (схема `core`)
- Данные очищены, нормализованы и приведены к целевым типам.
- Модель «звезда»: центральная таблица фактов и несколько измерений.
- Для измерения `dim_customer` реализован **SCD Type 2** (историчность изменений города клиента).
- Таблицы:
  - **Факты:** `fct_order_items`
  - **Измерения:** `dim_customer`, `dim_product`, `dim_seller`, `dim_date`

Связи:
- `fct_order_items.customer_sk` → `dim_customer.customer_sk` (один‑ко‑многим)
- `fct_order_items.product_sk` → `dim_product.product_sk` (один‑ко‑многим)
- `fct_order_items.seller_sk` → `dim_seller.seller_sk` (один‑ко‑многим)
- `fct_order_items.order_date_sk` → `dim_date.date_sk` (один‑ко‑многим)

### Mart (схема `mart`)
- Агрегированные витрины для отчётности и BI.
- Витрины:
  - `daily_sales` — ежедневная выручка и количество заказов.
  - `category_sales` — продажи по категориям товаров и месяцам.
  - `customer_rfm` — RFM‑сегментация клиентов (Recency, Frequency, Monetary).
- Все витрины используют данные только из Core‑слоя.
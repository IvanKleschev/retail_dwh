# Source‑to‑Target маппинг (S2T)

Здесь описан переход данных из Staging в Core для ключевых таблиц.

## dim_customer (SCD2)
| Источник (staging) | Приёмник (core) | Логика трансформации |
| :--- | :--- | :--- |
| `raw_olist_customers.customer_id` | `dim_customer.customer_id` | Прямое отображение |
| `raw_olist_customers.customer_unique_id` | `dim_customer.customer_unique_id` | Прямое отображение |
| `raw_olist_customers.customer_city` | `dim_customer.customer_city` | Очистка, приведение к VARCHAR(50) |
| `raw_olist_customers.customer_state` | `dim_customer.customer_state` | Очистка, приведение к VARCHAR(50) |
| Вычисляется из заказов | `dim_customer.effective_from` | Минимальная дата заказа с данным городом |
| Вычисляется | `dim_customer.effective_to` | Дата начала следующей версии минус 1 секунда, либо '9999-12-31' |
| Вычисляется | `dim_customer.is_current` | TRUE, если effective_to = '9999-12-31' |

## fct_order_items
| Источник (staging) | Приёмник (core) | Логика трансформации |
| :--- | :--- | :--- |
| `raw_olist_order_items.order_id` | `fct_order_items.order_id` | Прямое отображение |
| `raw_olist_order_items.price` | `fct_order_items.price` | Приведение к NUMERIC(10,2) |
| `raw_olist_order_items.freight_value` | `fct_order_items.freight_value` | Приведение к NUMERIC(10,2) |
| `raw_olist_orders.order_status` | `fct_order_items.order_status` | Прямое отображение |
| Дата заказа + dim_date | `fct_order_items.order_date_sk` | Поиск суррогатного ключа в dim_date по дате |
| customer_id + дата | `fct_order_items.customer_sk` | Поиск актуальной версии в dim_customer (SCD2) |
| ... | ... | ... |

Остальные маппинги аналогичны (прямое копирование с приведением типов).
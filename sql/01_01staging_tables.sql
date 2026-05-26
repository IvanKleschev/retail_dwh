-- все csv файлы были успешно импортированы, кроме отзывов, для него отдельно создали таблицу с форматами TEXT, VARCHAR(256) не помещался
CREATE TABLE staging.raw_order_reviews (
    review_id TEXT,
    order_id TEXT,
    review_score TEXT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TEXT,
    review_answer_timestamp TEXT
);
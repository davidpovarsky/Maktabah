use tantivy::schema::*;

pub const FIELD_TYPE: &str = "type";
pub const TYPE_LINE: &str = "line";
pub const TYPE_BOOK_TITLE: &str = "book_title";
pub const FIELD_BOOK_ID: &str = "book_id";
pub const FIELD_CATEGORY_ID: &str = "category_id";
pub const FIELD_ANCESTOR_CATEGORY_IDS: &str = "ancestor_category_ids";
pub const FIELD_BOOK_TITLE: &str = "book_title";
pub const FIELD_LINE_ID: &str = "line_id";
pub const FIELD_LINE_INDEX: &str = "line_index";
pub const FIELD_TEXT: &str = "text";
pub const FIELD_TEXT_NG4: &str = "text_ng4";
pub const FIELD_TITLE: &str = "title";
pub const FIELD_ORDER_INDEX: &str = "order_index";
pub const FIELD_IS_BASE_BOOK: &str = "is_base_book";

pub fn expected_schema() -> Schema {
    let mut b = Schema::builder();
    b.add_text_field(FIELD_TYPE, STRING);
    b.add_i64_field(FIELD_BOOK_ID, INDEXED | STORED | FAST);
    b.add_i64_field(FIELD_CATEGORY_ID, INDEXED | STORED | FAST);
    b.add_i64_field(FIELD_ANCESTOR_CATEGORY_IDS, INDEXED | FAST);
    b.add_text_field(FIELD_BOOK_TITLE, STORED);
    b.add_i64_field(FIELD_LINE_ID, INDEXED | STORED | FAST);
    b.add_i64_field(FIELD_LINE_INDEX, INDEXED | STORED | FAST);
    b.add_text_field(FIELD_TEXT, TEXT);
    b.add_text_field(FIELD_TEXT_NG4, TEXT);
    b.add_text_field(FIELD_TITLE, TEXT | STORED);
    b.add_i64_field(FIELD_ORDER_INDEX, INDEXED | STORED | FAST);
    b.add_i64_field(FIELD_IS_BASE_BOOK, INDEXED | STORED | FAST);
    b.build()
}

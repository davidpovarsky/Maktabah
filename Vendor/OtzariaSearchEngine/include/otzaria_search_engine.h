#ifndef OTZARIA_SEARCH_ENGINE_H
#define OTZARIA_SEARCH_ENGINE_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void *OtzariaSearchEngineHandle;

OtzariaSearchEngineHandle otzaria_search_engine_new(const char *index_path);
void otzaria_search_engine_free(OtzariaSearchEngineHandle handle);

char *otzaria_search_engine_add_text_book_json(OtzariaSearchEngineHandle handle, const char *book_json);
char *otzaria_search_engine_add_pdf_book_json(OtzariaSearchEngineHandle handle, const char *book_json);
char *otzaria_search_engine_search_json(OtzariaSearchEngineHandle handle, const char *request_json);
char *otzaria_search_engine_book_counts_json(OtzariaSearchEngineHandle handle, const char *request_json);
char *otzaria_search_engine_facet_counts_json(OtzariaSearchEngineHandle handle, const char *request_json, const char *facet_prefix);
char *otzaria_search_engine_set_bulk_indexing(OtzariaSearchEngineHandle handle, bool enabled);
char *otzaria_search_engine_clear(OtzariaSearchEngineHandle handle);
char *otzaria_search_engine_commit(OtzariaSearchEngineHandle handle);
char *otzaria_search_engine_rollback(OtzariaSearchEngineHandle handle);
char *otzaria_search_engine_optimize(OtzariaSearchEngineHandle handle);
char *otzaria_search_engine_document_count(OtzariaSearchEngineHandle handle);
char *otzaria_search_engine_indexed_file_paths(OtzariaSearchEngineHandle handle);
char *otzaria_search_engine_book_fingerprints(OtzariaSearchEngineHandle handle);
char *otzaria_search_engine_delete_file_paths_json(OtzariaSearchEngineHandle handle, const char *file_paths_json);
char *otzaria_search_engine_check_compatibility(const char *index_path);
char *otzaria_search_engine_build_info(void);
char *otzaria_search_engine_set_dictionaries_json(OtzariaSearchEngineHandle handle, const char *paths_json);
char *otzaria_search_engine_helper_json(const char *request_json);
char *otzaria_search_engine_semantic_json(OtzariaSearchEngineHandle handle, const char *request_json);

void otzaria_search_engine_free_string(char *value);

#ifdef __cplusplus
}
#endif

#endif /* OTZARIA_SEARCH_ENGINE_H */

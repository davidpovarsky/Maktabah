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

char *otzaria_search_engine_add_documents_json(OtzariaSearchEngineHandle handle, const char *documents_json);
char *otzaria_search_engine_search_json(OtzariaSearchEngineHandle handle, const char *request_json);
char *otzaria_search_engine_clear(OtzariaSearchEngineHandle handle);
char *otzaria_search_engine_commit(OtzariaSearchEngineHandle handle);
char *otzaria_search_engine_optimize(OtzariaSearchEngineHandle handle);
char *otzaria_search_engine_document_count(OtzariaSearchEngineHandle handle);
char *otzaria_search_engine_indexed_file_paths(OtzariaSearchEngineHandle handle);

void otzaria_search_engine_free_string(char *value);

#ifdef __cplusplus
}
#endif

#endif /* OTZARIA_SEARCH_ENGINE_H */

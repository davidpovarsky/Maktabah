#ifndef OTZARIA_SEARCH_ENGINE_H
#define OTZARIA_SEARCH_ENGINE_H

#include <stdbool.h>
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void *OtzariaSearchEngineHandle;

OtzariaSearchEngineHandle otzaria_search_engine_new(const char *index_path);
char *otzaria_search_engine_last_init_error(void);
OtzariaSearchEngineHandle otzaria_search_engine_new_with_error(const char *index_path, char **out_error_json);
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

/* Exact single-analyzed-token occurrences, request contract version 1.
 *
 * Request tokens are non-reused integer IDs, not dereferenceable pointers.
 * Zero means creation failed. At most 64 tokens may be live; release each token.
 *
 * The JSON buffer must be readable for request_length bytes during new(); it
 * need not be NUL-terminated. Input is capped at 512 KiB. out_error_json is a
 * writable char* slot or NULL. Free returned error/result strings with
 * otzaria_search_engine_free_string().
 *
 * Required JSON: {"version":1,"mode":"exact","query":"...","timeoutMs":5000}.
 * Optional: facets, bookIds, limits (maxCandidateDocuments, maxPositions,
 * maxPositionsPerDocument, maxSegments). Unknown fields/modes are rejected.
 * Engine defaults and hard bounds are retained. timeoutMs is 0...60000 and
 * starts at new(), before parsing, scheduling, and any engine-mutex wait.
 *
 * execute is synchronous, single-use and intended for a worker thread.
 * The caller must keep the genuine EngineHandle alive until execute returns;
 * engine_free must not race with this or other existing engine calls.
 * cancel/release may race with execute safely. release also cancels an in-flight
 * retained request. Cancellation after the final publication check cannot
 * retroactively revoke a result that has already returned.
 *
 * Failure JSON: {"ok":false,"value":null,"error":{"code":"...","message":"..."}}.
 * A failure never includes a partial occurrence scalar. Success certifies only
 * the original held index snapshot, with full source/segment/delete proof;
 * the host must separately establish catalogue, corpus and invocation identity.
 */
typedef uint64_t OtzariaOccurrenceRequest;

OtzariaOccurrenceRequest otzaria_search_engine_occurrence_request_new(
    const uint8_t *request_json, size_t request_length, char **out_error_json);
bool otzaria_search_engine_occurrence_request_cancel(OtzariaOccurrenceRequest request);
bool otzaria_search_engine_occurrence_request_release(OtzariaOccurrenceRequest request);
char *otzaria_search_engine_count_occurrences_json(
    OtzariaSearchEngineHandle handle, OtzariaOccurrenceRequest request);

void otzaria_search_engine_free_string(char *value);

#ifdef __cplusplus
}
#endif

#endif /* OTZARIA_SEARCH_ENGINE_H */

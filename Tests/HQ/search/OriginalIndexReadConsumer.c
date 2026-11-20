/* A read-only external consumer of the actual original C ABI.
 * No add, commit, delete, clear, optimize, or index-build entry point is used.
 * Input: ASCII-owned index path, UTF-8 commands file (id<TAB>op<TAB>JSON).
 * Every returned allocation is freed using the public ABI.
 */
#include "otzaria_search_engine.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int emit(const char *name, char *value) {
    if (value == NULL) {
        fprintf(stderr, "NULL response: %s\n", name);
        return 0;
    }
    printf("OTZARIA_QUAL\t%s\t%s\n", name, value);
    fflush(stdout);
    otzaria_search_engine_free_string(value);
    return 1;
}

int main(int argc, char **argv) {
    if (argc != 3) return 2;
    FILE *commands = fopen(argv[2], "rb");
    if (commands == NULL) return 3;
    if (!emit("build_info", otzaria_search_engine_build_info()) ||
        !emit("compatibility", otzaria_search_engine_check_compatibility(argv[1]))) {
        fclose(commands); return 4;
    }
    char *error = NULL;
    OtzariaSearchEngineHandle engine = otzaria_search_engine_new_with_error(argv[1], &error);
    if (engine == NULL) {
        if (error != NULL) emit("open_error", error);
        fclose(commands); return 5;
    }
    if (error != NULL) { otzaria_search_engine_free_string(error); }
    printf("OTZARIA_QUAL\topened\t{\"opened\":true}\n");
    int ok = emit("document_count_before", otzaria_search_engine_document_count(engine)) &&
             emit("indexed_file_paths", otzaria_search_engine_indexed_file_paths(engine)) &&
             emit("book_fingerprints", otzaria_search_engine_book_fingerprints(engine));
    const size_t line_capacity = 1024 * 1024;
    char *line = malloc(line_capacity);
    if (line == NULL) {
        fclose(commands); otzaria_search_engine_free(engine); return 7;
    }
    while (ok && fgets(line, (int)line_capacity, commands) != NULL) {
        size_t length = strlen(line);
        if (length == 0 || line[length - 1] != '\n') { ok = 0; break; }
        while (length && (line[length - 1] == '\r' || line[length - 1] == '\n')) line[--length] = 0;
        char *operation = strchr(line, '\t');
        if (operation == NULL) { ok = 0; break; }
        *operation++ = 0;
        char *request = strchr(operation, '\t');
        if (request == NULL) { ok = 0; break; }
        *request++ = 0;
        char *result = NULL;
        if (strcmp(operation, "search") == 0) {
            result = otzaria_search_engine_search_json(engine, request);
        } else if (strcmp(operation, "books") == 0) {
            result = otzaria_search_engine_book_counts_json(engine, request);
        } else if (strcmp(operation, "facets") == 0) {
            result = otzaria_search_engine_facet_counts_json(engine, request, "/");
#ifdef HAS_OCCURRENCES
        } else if (strcmp(operation, "occurrences") == 0) {
            char *request_error = NULL;
            OtzariaOccurrenceRequest token = otzaria_search_engine_occurrence_request_new(
                (const uint8_t *)request, strlen(request), &request_error);
            if (token == 0) {
                result = request_error;
            } else {
                if (request_error != NULL) otzaria_search_engine_free_string(request_error);
                result = otzaria_search_engine_count_occurrences_json(engine, token);
                if (!otzaria_search_engine_occurrence_request_release(token)) {
                    if (result != NULL) otzaria_search_engine_free_string(result);
                    ok = 0; break;
                }
            }
#endif
        } else {
            fprintf(stderr, "Unknown operation %s\n", operation); ok = 0; break;
        }
        ok = emit(line, result);
    }
    if (ferror(commands)) ok = 0;
    free(line);
    fclose(commands);
    if (ok) ok = emit("document_count_after", otzaria_search_engine_document_count(engine));
    otzaria_search_engine_free(engine);
    printf("OTZARIA_QUAL\tclosed\t{\"closed\":true}\n");
    return ok ? 0 : 6;
}

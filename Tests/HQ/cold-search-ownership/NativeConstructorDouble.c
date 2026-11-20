/* Explicit native boundary double. This does not execute or qualify d5/Tantivy.
 * Unused native APIs abort; the fixture cannot accidentally run a search,
 * install, write, recovery, occurrence request or semantic engine operation. */
#define _POSIX_C_SOURCE 200809L
#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static _Atomic uint64_t constructors, closes, counts, dictionaries, compatibilities;
static _Atomic uint64_t document_count = 17;
static _Atomic int compatibility_mode, configuration_ok = 1, constructor_failure;
extern void cold_fixture_after_constructor(void);
static char *response(const char *value) { return strdup(value); }
void cold_fixture_reset(void) {
    constructors = closes = counts = dictionaries = compatibilities = 0;
    document_count = 17; compatibility_mode = 0; configuration_ok = 1; constructor_failure = 0;
}
void cold_fixture_set_compatibility(int32_t value) { compatibility_mode = value; }
void cold_fixture_set_count(uint64_t value) { document_count = value; }
void cold_fixture_set_configuration(int32_t value) { configuration_ok = value; }
void cold_fixture_set_constructor_failure(int32_t value) { constructor_failure = value; }
void cold_fixture_stats(uint64_t *out) {
    out[0] = constructors; out[1] = closes; out[2] = counts; out[3] = dictionaries; out[4] = compatibilities;
}
void *otzaria_search_engine_new_with_error(const char *path, char **error) {
    (void)path; constructors++;
    if (constructor_failure) {
        *error = response("{\"code\":\"FIXTURE_CONSTRUCTOR_FAILURE\",\"message\":\"explicit native double\"}");
        return NULL;
    }
    cold_fixture_after_constructor();
    return malloc(1);
}
char *otzaria_search_engine_last_init_error(void) { return NULL; }
void otzaria_search_engine_free(void *handle) { closes++; free(handle); }
void otzaria_search_engine_free_string(char *value) { free(value); }
char *otzaria_search_engine_document_count(void *handle) {
    if (!handle) { abort(); }
    counts++;
    char value[160]; snprintf(value, sizeof(value), "{\"ok\":true,\"value\":%llu}", (unsigned long long)document_count);
    return response(value);
}
char *otzaria_search_engine_set_dictionaries_json(void *handle, const char *json) {
    (void)json;
    if (!handle) { abort(); }
    dictionaries++;
    return response(configuration_ok ?
        "{\"ok\":true,\"value\":{\"translation\":true,\"acronyms\":true,\"magic\":false}}" :
        "{\"ok\":true,\"value\":{\"translation\":false,\"acronyms\":true,\"magic\":false}}");
}
char *otzaria_search_engine_check_compatibility(const char *path) {
    (void)path; compatibilities++;
    const char *status = compatibility_mode == 1 ? "legacy_compatible" : compatibility_mode == 2 ? "rebuild_required" : "compatible";
    char value[500]; snprintf(value, sizeof(value),
        "{\"ok\":true,\"value\":{\"compatible\":%s,\"status\":\"%s\",\"foundSchemaVersion\":4,\"requiredSchemaVersion\":4,\"engineVersion\":\"explicit-double\",\"metadataPath\":\"explicit-double\",\"reason\":null}}",
        compatibility_mode == 2 ? "false" : "true", status);
    return response(value);
}
/* The generator appends abort-only definitions for every other original
 * @_silgen_name symbol, so the whole Swift bridge links without replacing it. */

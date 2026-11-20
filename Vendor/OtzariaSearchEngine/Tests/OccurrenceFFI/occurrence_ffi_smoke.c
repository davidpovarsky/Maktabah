/* External C caller of the shipped header and real static library.
 * Run only through run-c-smoke.py, which owns its TemporaryDirectory.
 * JSON assertions live in that driver and are independent of bridge helpers.
 */
#include "otzaria_search_engine.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

static int emit(const char *stage, char *result) {
    if (result == NULL) {
        fprintf(stderr, "null JSON at %s\n", stage);
        return 0;
    }
    printf("{\"stage\":\"%s\",\"result\":%s}\n", stage, result);
    otzaria_search_engine_free_string(result);
    return 1;
}

static int flag(const char *stage, bool result) {
    printf("{\"stage\":\"%s\",\"result\":%s}\n", stage, result ? "true" : "false");
    return result ? 1 : 0;
}

static OtzariaOccurrenceRequest request(const char *json) {
    char *error = NULL;
    OtzariaOccurrenceRequest token = otzaria_search_engine_occurrence_request_new(
        (const uint8_t *)json, strlen(json), &error);
    if (token == 0) {
        emit("unexpectedRequestError", error);
    } else if (error != NULL) {
        otzaria_search_engine_free_string(error);
        otzaria_search_engine_occurrence_request_release(token);
        return 0;
    }
    return token;
}

int main(int argc, char **argv) {
    static const char owner[] = "otzaria-occurrence-c-smoke-disposable-v1\n";
    static const char exact[] =
        "{\"version\":1,\"mode\":\"exact\",\"query\":\"\\u05de\\u05e9\\u05d4\","
        "\"timeoutMs\":5000,\"bookIds\":[1]}";
    char marker[4096], index[4096], metadata[4096], marker_value[128] = {0};
    struct stat info;
    FILE *file;
    OtzariaSearchEngineHandle engine = NULL;
    OtzariaOccurrenceRequest token = 0;
    char *error = NULL;
    int rc = 1;
    if (argc != 2 || strlen(argv[1]) > 3900) {
        fprintf(stderr, "requires the driver's explicitly owned disposable directory\n");
        return 2;
    }
    snprintf(marker, sizeof(marker), "%s/OWNER", argv[1]);
    snprintf(index, sizeof(index), "%s/index", argv[1]);
    snprintf(metadata, sizeof(metadata), "%s/index/meta.json", argv[1]);
    file = fopen(marker, "rb");
    if (file == NULL) return 3;
    if (fread(marker_value, 1, sizeof(marker_value) - 1, file) != strlen(owner)) {
        fclose(file); return 4;
    }
    fclose(file);
    if (strcmp(marker_value, owner) != 0 || stat(metadata, &info) == 0) return 5;

    engine = otzaria_search_engine_new_with_error(index, &error);
    if (engine == NULL) {
        emit("initError", error);
        return 6;
    }
    if (error != NULL) { otzaria_search_engine_free_string(error); goto cleanup; }
    if (!emit("buildInfo", otzaria_search_engine_build_info())) goto cleanup;
    if (!emit("add", otzaria_search_engine_add_text_book_json(engine,
        "{\"title\":\"external C owned fixture\",\"topics\":\"/fixtures\","
        "\"filePath\":\"otzaria-book:1\",\"catalogueOrder\":1,"
        "\"text\":\"\\u05de\\u05e9\\u05d4 \\u05de\\u05e9\\u05d4\","
        "\"extraFacets\":[\"/book/1\",\"/author/a\"]}"))) goto cleanup;
    if (!emit("commit", otzaria_search_engine_commit(engine))) goto cleanup;
    if (!emit("legacySearch", otzaria_search_engine_search_json(engine,
        "{\"query\":\"\\u05de\\u05e9\\u05d4\",\"mode\":\"exact\","
        "\"facets\":[\"/\"],\"limit\":100}"))) goto cleanup;

    token = request(exact);
    if (token == 0) goto cleanup;
    printf("{\"stage\":\"requestToken\",\"result\":%llu}\n", (unsigned long long)token);
    if (!emit("exactCount", otzaria_search_engine_count_occurrences_json(engine, token))) goto cleanup;
    if (!emit("duplicateExecution", otzaria_search_engine_count_occurrences_json(engine, token))) goto cleanup;
    if (!flag("releaseCompleted", otzaria_search_engine_occurrence_request_release(token))) goto cleanup;
    token = 0;

    token = request(exact);
    if (token == 0) goto cleanup;
    if (!flag("cancel", otzaria_search_engine_occurrence_request_cancel(token))) goto cleanup;
    if (!emit("cancelledCount", otzaria_search_engine_count_occurrences_json(engine, token))) goto cleanup;
    if (!flag("releaseCancelled", otzaria_search_engine_occurrence_request_release(token))) goto cleanup;
    flag("releaseTwice", otzaria_search_engine_occurrence_request_release(token));
    token = 0;

    token = request("{\"version\":1,\"mode\":\"exact\",\"query\":\"x\",\"timeoutMs\":0}");
    if (token == 0) goto cleanup;
    if (!emit("expiredCount", otzaria_search_engine_count_occurrences_json(engine, token))) goto cleanup;
    if (!flag("releaseExpired", otzaria_search_engine_occurrence_request_release(token))) goto cleanup;
    token = 0;

    error = NULL;
    token = otzaria_search_engine_occurrence_request_new(
        (const uint8_t *)"{", 1, &error);
    if (token != 0 || !emit("malformedRequest", error)) goto cleanup;
    rc = 0;
cleanup:
    if (token != 0) otzaria_search_engine_occurrence_request_release(token);
    /* Every synchronous call returned before releasing the genuine engine. */
    otzaria_search_engine_free(engine);
    return rc;
}

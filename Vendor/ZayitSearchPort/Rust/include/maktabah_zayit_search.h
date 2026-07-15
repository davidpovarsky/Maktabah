#ifndef MAKTABAH_ZAYIT_SEARCH_H
#define MAKTABAH_ZAYIT_SEARCH_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
char *mzayit_validate_paths(const char *paths_json);
char *mzayit_engine_create(const char *paths_json);
char *mzayit_engine_search(uint64_t engine_id, const char *request_json);
void mzayit_engine_destroy(uint64_t engine_id);
void mzayit_string_free(char *value);
#ifdef __cplusplus
}
#endif
#endif

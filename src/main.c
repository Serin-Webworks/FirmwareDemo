#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>

#define MAGIC_BYTES "SRN1"

static void write_padded(FILE *f, const char *s, size_t len) {
    size_t slen = s ? strlen(s) : 0;
    if (slen > len) {
        slen = len;
    }
    if (slen > 0) {
        fwrite(s, 1, slen, f);
    }
    for (size_t i = slen; i < len; i++) {
        fputc(0, f);
    }
}

static uint32_t hash_version(const char *s) {
    uint32_t h = 2166136261u;
    while (*s) {
        h ^= (uint8_t)(*s++);
        h *= 16777619u;
    }
    return h;
}

static uint8_t next_byte(uint32_t *state) {
    *state = (*state * 1664525u) + 1013904223u;
    return (uint8_t)((*state >> 24) & 0xFF);
}

int main(void) {
    const char *version = getenv("VERSION");
    const char *output = getenv("OUTPUT");
    const char *build_ts = getenv("BUILD_TS");
    const char *git_hash = getenv("GIT_HASH");
    const char *payload_len_str = getenv("PAYLOAD_LEN");

    if (!version || !output || !build_ts || !git_hash || !payload_len_str) {
        fprintf(stderr, "Missing required environment variables.\n");
        fprintf(stderr, "Expected VERSION, OUTPUT, BUILD_TS, GIT_HASH, PAYLOAD_LEN.\n");
        return 1;
    }

    errno = 0;
    long payload_len_long = strtol(payload_len_str, NULL, 10);
    if (errno != 0 || payload_len_long <= 0 || payload_len_long > 50 * 1024 * 1024) {
        fprintf(stderr, "Invalid PAYLOAD_LEN: %s\n", payload_len_str);
        return 1;
    }
    uint32_t payload_len = (uint32_t)payload_len_long;

    FILE *f = fopen(output, "wb");
    if (!f) {
        fprintf(stderr, "Failed to open output: %s\n", output);
        return 1;
    }

    fwrite(MAGIC_BYTES, 1, 4, f);
    write_padded(f, version, 16);
    write_padded(f, build_ts, 20);
    write_padded(f, git_hash, 8);

    uint8_t len_bytes[4];
    len_bytes[0] = (uint8_t)(payload_len & 0xFF);
    len_bytes[1] = (uint8_t)((payload_len >> 8) & 0xFF);
    len_bytes[2] = (uint8_t)((payload_len >> 16) & 0xFF);
    len_bytes[3] = (uint8_t)((payload_len >> 24) & 0xFF);
    fwrite(len_bytes, 1, 4, f);

    uint32_t state = hash_version(version);
    for (uint32_t i = 0; i < payload_len; i++) {
        fputc((int)next_byte(&state), f);
    }

    fclose(f);
    return 0;
}

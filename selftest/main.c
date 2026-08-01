/* Fixture for the reusable-workflow self-test.
 *
 * Calls into zlib so the produced binary has a genuine shared-library
 * dependency for bundle-linux-libs.sh / bundle-macos-dylibs.sh to relocate,
 * and prints a sentinel the smoke test greps for. */

#include <stdio.h>
#include <string.h>
#include <zlib.h>

int main(void)
{
    /* Round-trip a buffer through zlib to prove the bundled library is not
     * merely present but actually loadable and callable. */
    const char *input = "silimate selftest payload";
    unsigned char compressed[128];
    char restored[128];

    uLongf compressed_len = sizeof(compressed);
    if (compress(compressed, &compressed_len, (const Bytef *)input,
                 (uLong)strlen(input) + 1) != Z_OK) {
        fprintf(stderr, "SELFTEST: compress failed\n");
        return 1;
    }

    uLongf restored_len = sizeof(restored);
    if (uncompress((Bytef *)restored, &restored_len, compressed,
                   compressed_len) != Z_OK) {
        fprintf(stderr, "SELFTEST: uncompress failed\n");
        return 1;
    }

    if (strcmp(input, restored) != 0) {
        fprintf(stderr, "SELFTEST: round trip mismatch\n");
        return 1;
    }

    printf("SELFTEST: PASS (zlib %s)\n", zlibVersion());
    return 0;
}

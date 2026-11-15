/* Cross-check the C tag against the MATLAB tag_test.txt vectors (written by test_tag.m).
 * SCNu64 keeps the 64-bit reads correct on Windows, where unsigned long is 32 bits. */
#include <stdio.h>
#include <inttypes.h>
#include "polytag.h"
int main(void) {
    FILE *f = fopen("../tag_test.txt", "r");
    if (!f) { printf("tag_test.txt not found: run test_tag in MATLAB first\n"); return 1; }
    uint64_t r, s, t, x[50]; int ok = 0, n = 0;
    while (fscanf(f, "%" SCNu64 " %" SCNu64 " %" SCNu64, &r, &s, &t) == 3) {
        for (int i = 0; i < 50; i++) if (fscanf(f, "%" SCNu64, &x[i]) != 1) return 1;
        n++; ok += pt_tag(x, 50, r, s) == t;
    }
    fclose(f);
    printf("C vs MATLAB tag vectors: %d/%d match\n", ok, n);
    return 0;
}

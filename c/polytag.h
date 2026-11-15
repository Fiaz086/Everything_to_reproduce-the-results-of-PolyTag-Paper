/* PolyTag reference implementation: tag over GF(2^61-1), keys from AES-128. */
#ifndef POLYTAG_H
#define POLYTAG_H
#include <stdint.h>
#include <stddef.h>
#define PT_P ((1ULL << 61) - 1)
static inline uint64_t pt_red(unsigned __int128 x) {
    uint64_t lo = (uint64_t)(x & PT_P), hi = (uint64_t)(x >> 61);
    uint64_t r = lo + hi;                 /* < 2^62 */
    r = (r & PT_P) + (r >> 61);
    return r >= PT_P ? r - PT_P : r;
}
static inline uint64_t pt_mul(uint64_t a, uint64_t b) { return pt_red((unsigned __int128)a * b); }
/* Horner: h = sum x_i r^(m-i+1); tag = h + s.  x_i already reduced (< p). */
static inline uint64_t pt_tag(const uint64_t *x, size_t m, uint64_t r, uint64_t s) {
    uint64_t h = 0;
    for (size_t i = 0; i < m; i++) { h += x[i]; if (h >= PT_P) h -= PT_P; h = pt_mul(h, r); }
    h += s; if (h >= PT_P) h -= PT_P;
    return h;
}
#endif

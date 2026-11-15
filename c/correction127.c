/* Keyed-syndrome localization and correction over GF(2^127 - 1) (paper, Section VII-B and X-J).
 *
 * 1. Correctness check: random quantized vectors of length m = 980 and 2244 (IEEE 118- and 300-bus),
 *    d = 1, 2, 3, 5, 501 vectors per scenario (honest, d changed entries, d + 1 changed entries,
 *    one altered tag): 2 x 4 x 4 x 501 = 16,032 decodes. Changes of 1-1000 quantization steps.
 * 2. Timing (m = 2244): tagging (PRF key derivation + 2d tags) and decoding of a vector with d
 *    changed entries (key derivation, syndromes, Berlekamp-Massey, root search, Vandermonde solve,
 *    fail-safe check). Median of 2,001 samples; on Windows each sample times K consecutive runs.
 * 3. Cross-check: if ../results/13_tag127_test.txt (written by run_13_correction.m) exists, the
 *    tags it lists are recomputed here and compared.
 * Keys: AES-128 in counter mode (OpenSSL); block 0 gives r (a block reducing to 0 is skipped),
 * blocks 1..2d give s_1..s_2d, each 128-bit block reduced modulo p.
 * Output (stdout, CSV): record,m,d,scenario,vectors,accepted_correct,rejected,wrong,median_ns
 * Build: gcc -O2 -march=native -o correction127 correction127.c -lcrypto  (Windows: see README) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <time.h>
#include <openssl/evp.h>
#ifdef _WIN32
#include <windows.h>
#endif
#if defined(__x86_64__) || defined(__i386__)
#include <cpuid.h>
#endif

typedef unsigned __int128 u128;
static const u128 P = (((u128)1) << 127) - 1;
#define MAXM 2244
#define MAXD 5

/* ---------------- field arithmetic ---------------- */
static inline u128 fold(u128 x) { x = (x & P) + (x >> 127); return x >= P ? x - P : x; }
static inline u128 fadd(u128 a, u128 b) { return fold(a + b); }
static inline u128 fsub(u128 a, u128 b) { return fold(a + (P - b)); }
static inline u128 fmul(u128 a, u128 b) {
    uint64_t a0 = (uint64_t)a, a1 = (uint64_t)(a >> 64), b0 = (uint64_t)b, b1 = (uint64_t)(b >> 64);
    u128 p00 = (u128)a0 * b0, mid = (u128)a0 * b1 + (u128)a1 * b0, p11 = (u128)a1 * b1;  /* mid < 2^128 */
    u128 lo = p00 + (mid << 64);
    u128 hi = p11 + (mid >> 64) + (lo < p00);       /* product = hi * 2^128 + lo, hi < 2^126 */
    u128 t = (lo & P) + (lo >> 127);                /* <= 2^127 */
    t = (t & P) + (t >> 127);                       /* < 2^127 */
    return fold(t + (hi << 1));                     /* 2^128 = 2 (mod p) */
}
static u128 fpow(u128 a, u128 e) { u128 r = 1; while (e) { if (e & 1) r = fmul(r, a); a = fmul(a, a); e >>= 1; } return r; }
static inline u128 finv(u128 a) { return fpow(a, P - 2); }
static inline u128 from_int(int64_t v) { return v >= 0 ? (u128)v : P - (u128)(-v); }

/* ---------------- PRF: AES-128 in counter mode ---------------- */
static EVP_CIPHER_CTX *aes;
static u128 prf_block(uint64_t slot, uint32_t idx) {
    unsigned char in[16] = {0}, out[16]; int l;
    memcpy(in, "PT", 2); memcpy(in + 2, &idx, 4); memcpy(in + 8, &slot, 8);
    EVP_EncryptUpdate(aes, out, &l, in, 16);
    u128 x; memcpy(&x, out, 16);
    return fold((x & P) + (x >> 127));
}
static void derive(uint64_t slot, int d, u128 *r, u128 *s) {
    uint32_t idx = 0;
    do { *r = prf_block(slot, idx++); } while (*r == 0);
    for (int l = 0; l < 2 * d; l++) s[l] = prf_block(slot, 1000 + l);
}

/* ---------------- tags and syndromes ---------------- */
/* sum_{i=1..m} z_i y^i by Horner */
static inline u128 hsum(const u128 *z, int m, u128 y) {
    u128 h = 0;
    for (int i = m - 1; i >= 0; i--) h = fmul(fadd(h, z[i]), y);
    return h;
}
static void make_tags(const u128 *z, int m, int d, uint64_t slot, u128 *tau) {
    u128 r, s[2 * MAXD]; derive(slot, d, &r, s);
    u128 y = r;
    for (int l = 0; l < 2 * d; l++) { tau[l] = fadd(s[l], hsum(z, m, y)); y = fmul(y, r); }
}

/* Decode: returns 1 accepted unchanged, 2 corrected and accepted (z corrected in place), 0 rejected. */
static int decode(u128 *z, int m, int d, uint64_t slot, const u128 *tauh) {
    u128 r, s[2 * MAXD], S[2 * MAXD]; derive(slot, d, &r, s);
    int allzero = 1; u128 y = r;
    for (int l = 0; l < 2 * d; l++) {
        S[l] = fsub(hsum(z, m, y), fsub(tauh[l], s[l]));
        if (S[l]) allzero = 0;
        y = fmul(y, r);
    }
    if (allzero) return 1;
    /* Berlekamp-Massey */
    u128 C[2 * MAXD + 1] = {1}, B[2 * MAXD + 1] = {1}, T[2 * MAXD + 1], b = 1;
    int L = 0, mm = 1, D = 2 * d + 1;
    for (int n = 0; n < 2 * d; n++) {
        u128 disc = S[n];
        for (int i = 1; i <= L; i++) disc = fadd(disc, fmul(C[i], S[n - i]));
        if (disc == 0) { mm++; continue; }
        u128 coef = fmul(disc, finv(b));
        memcpy(T, C, sizeof(u128) * D);
        for (int k = 0; k + mm < D; k++) C[k + mm] = fsub(C[k + mm], fmul(coef, B[k]));
        if (2 * L <= n) { L = n + 1 - L; memcpy(B, T, sizeof(u128) * D); b = disc; mm = 1; }
        else mm++;
    }
    if (L < 1 || L > d) return 0;
    /* root search: C(r^-i) = 0 */
    u128 ri = finv(r), x = 1; int pos[MAXD], nr = 0;
    for (int i = 1; i <= m; i++) {
        x = fmul(x, ri);
        u128 v = C[L];
        for (int k = L - 1; k >= 0; k--) v = fadd(fmul(v, x), C[k]);
        if (v == 0) { if (nr == L) return 0; pos[nr++] = i; }
    }
    if (nr != L) return 0;
    /* Vandermonde solve: sum_j Delta_j X_j^l = S_l, l = 1..L */
    u128 Xj[MAXD], A[2 * MAXD][MAXD], M[MAXD][MAXD + 1];
    for (int j = 0; j < L; j++) { Xj[j] = fpow(r, (u128)pos[j]); A[0][j] = Xj[j]; for (int l = 1; l < 2 * d; l++) A[l][j] = fmul(A[l - 1][j], Xj[j]); }
    for (int l = 0; l < L; l++) { for (int j = 0; j < L; j++) M[l][j] = A[l][j]; M[l][L] = S[l]; }
    for (int k = 0; k < L; k++) {
        u128 iv = finv(M[k][k]);
        for (int j = k; j <= L; j++) M[k][j] = fmul(M[k][j], iv);
        for (int l = 0; l < L; l++) if (l != k) { u128 f = M[l][k]; for (int j = k; j <= L; j++) M[l][j] = fsub(M[l][j], fmul(f, M[k][j])); }
    }
    /* fail-safe: all 2d syndromes reproduced */
    for (int l = 0; l < 2 * d; l++) {
        u128 acc = 0;
        for (int j = 0; j < L; j++) acc = fadd(acc, fmul(M[j][L], A[l][j]));
        if (acc != S[l]) return 0;
    }
    for (int j = 0; j < L; j++) z[pos[j] - 1] = fsub(z[pos[j] - 1], M[j][L]);
    return 2;
}

/* ---------------- platform, timing ---------------- */
static void report_cpu(void) {
    char brand[49] = "unknown";
#if defined(__x86_64__) || defined(__i386__)
    unsigned int rr[12];
    if (__get_cpuid_max(0x80000000u, NULL) >= 0x80000004u) {
        for (unsigned int i = 0; i < 3; i++) __get_cpuid(0x80000002u + i, &rr[4*i], &rr[4*i+1], &rr[4*i+2], &rr[4*i+3]);
        memcpy(brand, rr, 48); brand[48] = 0;
    }
    unsigned int a, b, c, dd;
    fprintf(stderr, "detected_cpu: %s\n", brand);
    if (__get_cpuid_max(0, NULL) >= 0x1A && __get_cpuid_count(0x1A, 0, &a, &b, &c, &dd) && a)
        fprintf(stderr, "core_type: %s\n", (a >> 24) == 0x40 ? "performance core (P-core)" : (a >> 24) == 0x20 ? "efficiency core (E-core)" : "other");
#else
    fprintf(stderr, "detected_cpu: %s\n", brand);
#endif
}
#ifdef _WIN32
static double qpf;
static double now_ns(void) { LARGE_INTEGER c; QueryPerformanceCounter(&c); return (double)c.QuadPart * qpf; }
static void platform_setup(void) {
    LARGE_INTEGER f; QueryPerformanceFrequency(&f); qpf = 1e9 / (double)f.QuadPart;
    SetThreadAffinityMask(GetCurrentThread(), 1); SetPriorityClass(GetCurrentProcess(), HIGH_PRIORITY_CLASS);
    SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_HIGHEST); Sleep(50);
    fprintf(stderr, "pinned_to: logical CPU 0, high priority\n");
}
#else
static double now_ns(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e9 + t.tv_nsec; }
static void platform_setup(void) {}
#endif
static int cmpd(const void *a, const void *b) { double x = *(const double *)a, y = *(const double *)b; return (x > y) - (x < y); }

/* ---------------- random test data ---------------- */
static uint64_t rs = 0x243F6A8885A308D3ULL;
static uint64_t rnd(void) { rs ^= rs << 13; rs ^= rs >> 7; rs ^= rs << 17; return rs; }
static void random_vector(u128 *z, int64_t *zi, int m) { for (int i = 0; i < m; i++) { zi[i] = (int64_t)(rnd() % 200001) - 100000; z[i] = from_int(zi[i]); } }
static void change_entries(u128 *z, int m, int k) {
    int used[MAXM] = {0};
    for (int c = 0; c < k; c++) {
        int i; do { i = (int)(rnd() % m); } while (used[i]); used[i] = 1;
        int64_t step = (int64_t)(rnd() % 1000) + 1; if (rnd() & 1) step = -step;
        z[i] = fadd(z[i], from_int(step));
    }
}

int main(void) {
    platform_setup(); report_cpu();
    static const unsigned char key[16] = "0123456789abcdef";
    aes = EVP_CIPHER_CTX_new(); EVP_EncryptInit_ex(aes, EVP_aes_128_ecb(), NULL, key, NULL); EVP_CIPHER_CTX_set_padding(aes, 0);
    printf("record,m,d,scenario,vectors,accepted_correct,rejected,wrong,median_ns\n");
    static u128 z0[MAXM], z[MAXM]; static int64_t zi[MAXM];
    const int ms[2] = {980, 2244}, ds[4] = {1, 2, 3, 5}; const char *sc[4] = {"honest", "d_changed", "d_plus_1_changed", "tag_altered"};
    uint64_t slot = 1;
    /* 1. correctness check */
    for (int a = 0; a < 2; a++) for (int b = 0; b < 4; b++) for (int c = 0; c < 4; c++) {
        int m = ms[a], d = ds[b], good = 0, rej = 0, wrong = 0;
        for (int v = 0; v < 501; v++, slot++) {
            u128 tau[2 * MAXD];
            random_vector(z0, zi, m); make_tags(z0, m, d, slot, tau);
            memcpy(z, z0, sizeof(u128) * m);
            if (c == 1) change_entries(z, m, d);
            if (c == 2) change_entries(z, m, d + 1);
            if (c == 3) { u128 e; do { e = fold(((u128)rnd() << 64) | rnd()); } while (e == 0); int l = (int)(rnd() % (2 * d)); tau[l] = fadd(tau[l], e); }
            int st = decode(z, m, d, slot, tau);
            if (st == 0) rej++;
            else if (memcmp(z, z0, sizeof(u128) * m) == 0) good++; else wrong++;
        }
        printf("check,%d,%d,%s,501,%d,%d,%d,\n", m, d, sc[c], good, rej, wrong);
        fprintf(stderr, "check m=%d d=%d %-17s accepted-correct %3d rejected %3d wrong %d\n", m, d, sc[c], good, rej, wrong);
    }
    /* 2. timing on m = 2244 */
    const int R = 2001; static double t[2001]; int m = 2244;
    for (int b = 0; b < 4; b++) {
        int d = ds[b]; u128 tau[2 * MAXD];
        random_vector(z0, zi, m);
        for (int kind = 0; kind < 2; kind++) {
            uint64_t base = 1000000 + 10000 * (uint64_t)b;
            make_tags(z0, m, d, base, tau);
            memcpy(z, z0, sizeof(u128) * m); change_entries(z, m, d);
            static u128 zd[MAXM];
            int K = 1;
#ifdef _WIN32
            { double c0 = now_ns(); for (int j = 0; j < 20; j++) { if (kind == 0) make_tags(z0, m, d, base + j, tau); else { memcpy(zd, z, sizeof(u128) * m); decode(zd, m, d, base, tau); } }
              double est = (now_ns() - c0) / 20.0; K = (int)(20000.0 / (est > 1 ? est : 1)) + 1; if (K > 2000) K = 2000; }
#endif
            if (kind == 0) make_tags(z0, m, d, base, tau);
            for (int rep = 0; rep < R; rep++) {
                double t0 = now_ns();
                for (int j = 0; j < K; j++) {
                    if (kind == 0) { u128 tt[2 * MAXD]; make_tags(z0, m, d, base + 1 + (uint64_t)rep * K + j, tt); }
                    else { memcpy(zd, z, sizeof(u128) * m); if (decode(zd, m, d, base, tau) != 2) { fprintf(stderr, "decode failed\n"); return 1; } }
                }
                t[rep] = (now_ns() - t0) / K;
            }
            qsort(t, R, sizeof(double), cmpd);
            printf("%s,%d,%d,d_changed,%d,,,,%.0f\n", kind == 0 ? "time_tag" : "time_decode", m, d, R, t[R / 2]);
            fprintf(stderr, "%s m=%d d=%d: median %.1f us (K=%d)\n", kind == 0 ? "tagging " : "decoding", m, d, t[R / 2] / 1000, K);
        }
    }
    /* 3. cross-check against MATLAB tags */
    FILE *f = fopen("../results/13_tag127_test.txt", "r");
    if (!f) fprintf(stderr, "cross-check: ../results/13_tag127_test.txt not found (run run_13_correction in MATLAB first)\n");
    else {
        int ok = 0, n = 0, d, mm2; char hx[40];
        while (fscanf(f, "%d %d", &d, &mm2) == 2) {
            u128 r, s[2 * MAXD], tau[2 * MAXD];
            u128 *vals[1 + 4 * MAXD]; vals[0] = &r; for (int l = 0; l < 2 * d; l++) { vals[1 + l] = &s[l]; vals[1 + 2 * d + l] = &tau[l]; }
            for (int k = 0; k < 1 + 4 * d; k++) {
                if (fscanf(f, "%39s", hx) != 1) return 1;
                u128 x = 0; for (char *q = hx; *q; q++) x = (x << 4) | (u128)(*q <= '9' ? *q - '0' : (*q | 32) - 'a' + 10);
                *vals[k] = x;
            }
            for (int i = 0; i < mm2; i++) { long long v; if (fscanf(f, "%lld", &v) != 1) return 1; z[i] = from_int(v); }
            u128 y = r;
            for (int l = 0; l < 2 * d; l++) { n++; ok += fadd(s[l], hsum(z, mm2, y)) == tau[l]; y = fmul(y, r); }
        }
        fclose(f);
        printf("crosscheck,%d,,,%d,%d,,,\n", 2244, n, ok);
        fprintf(stderr, "cross-check with MATLAB tags: %d/%d match\n", ok, n);
    }
    return 0;
}

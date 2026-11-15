/* Per-vector authentication cost: PolyTag (incl. AES-128 key derivation) vs
 * RP-VDVM (6 PRF coefficients + degree-5 Horner per measurement) vs OpenSSL
 * HMAC-SHA256, AES-128-CMAC, AES-128-GMAC, Poly1305.  Median of 2,001 repetitions.
 *
 * Reference platform (paper, Section IX and Table 8): HP laptop with an
 * Intel Core i7-1255U processor (10 cores); GCC -O2 -march=native; OpenSSL 3.
 * The benchmark is single-threaded (one core). The CPU actually used is printed
 * to stderr at start-up, so it can be stored next to the CSV:
 *   ./bench > ../results/12_bench.csv 2> ../results/12_bench_platform.txt
 * Timings depend on the CPU: re-run on the reference platform before quoting them.
 *
 * Windows build (MinGW-w64): timing uses QueryPerformanceCounter, and the thread is
 * pinned to logical CPU 0 with high priority. On the hybrid i7-1255U, CPU 0 is a
 * performance (P) core; the core type actually used is printed to stderr.
 * The Windows timer usually ticks every 100 ns, too coarse for single runs of a few
 * hundred ns, so on Windows each of the 2,001 samples times K consecutive runs and
 * reports their mean; K is chosen so that a sample lasts at least 20 us. Every run
 * uses fresh key material (its own slot / nonce). On Linux K = 1. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#ifdef _WIN32
#include <windows.h>
#endif
#include <openssl/evp.h>
#include <openssl/core_names.h>
#include <openssl/params.h>
#include "polytag.h"
#if defined(__x86_64__) || defined(__i386__)
#include <cpuid.h>
#endif

/* Print the CPU brand string (x86 CPUID leaves 0x80000002-4) to stderr. */
static void report_cpu(void) {
    char brand[49] = "unknown (non-x86 or CPUID unavailable)";
#if defined(__x86_64__) || defined(__i386__)
    unsigned int r[12];
    if (__get_cpuid_max(0x80000000u, NULL) >= 0x80000004u) {
        for (unsigned int i = 0; i < 3; i++)
            __get_cpuid(0x80000002u + i, &r[4*i], &r[4*i+1], &r[4*i+2], &r[4*i+3]);
        memcpy(brand, r, 48); brand[48] = 0;
    }
#endif
    fprintf(stderr, "reference_platform_in_paper: HP laptop, Intel Core i7-1255U (10 cores)\n");
    fprintf(stderr, "detected_cpu: %s\n", brand);
#if defined(__x86_64__) || defined(__i386__)
    /* Hybrid CPUs (CPUID leaf 0x1A): core type of the core this thread runs on. */
    unsigned int a, b, c, d;
    if (__get_cpuid_max(0, NULL) >= 0x1A && __get_cpuid_count(0x1A, 0, &a, &b, &c, &d) && a) {
        unsigned int type = a >> 24;
        fprintf(stderr, "core_type: %s\n", type == 0x40 ? "performance core (P-core)" :
                                           type == 0x20 ? "efficiency core (E-core)" : "other");
    }
#endif
}

#ifdef _WIN32
static double qpf;
static double now_ns(void){ LARGE_INTEGER c; QueryPerformanceCounter(&c); return (double)c.QuadPart * qpf; }
static void platform_setup(void){
    LARGE_INTEGER f; QueryPerformanceFrequency(&f); qpf = 1e9 / (double)f.QuadPart;
    SetThreadAffinityMask(GetCurrentThread(), 1);          /* logical CPU 0 */
    SetPriorityClass(GetCurrentProcess(), HIGH_PRIORITY_CLASS);
    SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_HIGHEST);
    Sleep(50);                                             /* let the migration take effect */
    fprintf(stderr, "pinned_to: logical CPU 0, high priority\n");
}
#else
static void platform_setup(void){}
#endif

#ifndef _WIN32
static double now_ns(void){ struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec*1e9+t.tv_nsec; }
#endif
static int cmpd(const void*a,const void*b){ double x=*(double*)a,y=*(double*)b; return (x>y)-(x<y); }
static unsigned char key[32] = "0123456789abcdef0123456789abcdef";

/* AES-128-ECB on one counter block -> (r, s) */
static EVP_CIPHER_CTX *aes;
static void prf_block(uint64_t ctr, unsigned char out[16]) {
    unsigned char in[16] = {0}; memcpy(in, &ctr, 8); int l;
    EVP_EncryptUpdate(aes, out, &l, in, 16);
}
static uint64_t polytag_vec(const uint64_t *x, size_t m, uint64_t slot) {
    unsigned char b[16]; prf_block(slot, b);
    uint64_t r, s; memcpy(&r, b, 8); memcpy(&s, b + 8, 8);
    r = pt_red(r); s = pt_red(s);           /* reduction bias about 2^-61 (Section V), negligible */
    return pt_tag(x, m, r, s);
}
static double rp_sink;
static void rpvdvm_vec(const double *x, double *d, size_t m, uint64_t slot) {
    unsigned char b[48];
    for (size_t i = 0; i < m; i++) {
        prf_block(slot * 1000003ULL + 3*i, b); prf_block(slot * 1000003ULL + 3*i + 1, b + 16); prf_block(slot * 1000003ULL + 3*i + 2, b + 32);
        double acc = 0;
        for (int k = 0; k < 6; k++) { uint64_t u; memcpy(&u, b + 8*k, 8);
            double z = -5.0 + 10.0 * (double)(u >> 11) * (1.0 / 9007199254740992.0);
            acc = acc * x[i] + z; }
        d[i] = acc;
    }
}
/* Persistent MAC contexts: algorithm fetched and keyed once (as a device would
 * keep them); per message only re-init (new IV for GMAC), update and final. */
typedef struct { EVP_MAC_CTX *ctx; int gmac; int poly; } macctx;
static macctx mac_new(const char *alg, const char *digest, const char *cipher, int klen) {
    EVP_MAC *mac = EVP_MAC_fetch(NULL, alg, NULL); macctx m; m.ctx = EVP_MAC_CTX_new(mac); m.gmac = !strcmp(alg, "GMAC"); m.poly = !strcmp(alg, "POLY1305");
    OSSL_PARAM ps[4]; int n = 0; static unsigned char iv[12] = {0};
    if (digest) ps[n++] = OSSL_PARAM_construct_utf8_string(OSSL_MAC_PARAM_DIGEST, (char*)digest, 0);
    if (cipher) ps[n++] = OSSL_PARAM_construct_utf8_string(OSSL_MAC_PARAM_CIPHER, (char*)cipher, 0);
    if (m.gmac) ps[n++] = OSSL_PARAM_construct_octet_string(OSSL_MAC_PARAM_IV, iv, 12);
    ps[n] = OSSL_PARAM_construct_end();
    if (!m.ctx || !EVP_MAC_init(m.ctx, key, klen, ps)) { fprintf(stderr, "init failed: %s\n", alg); exit(1); }
    EVP_MAC_free(mac); return m;
}
static size_t mac_run(macctx *m, const unsigned char *msg, size_t len, unsigned char *out, uint64_t nonce) {
    size_t ol = 0;
    if (m->gmac) { unsigned char iv[12] = {0}; memcpy(iv, &nonce, 8);
        OSSL_PARAM ps[2] = { OSSL_PARAM_construct_octet_string(OSSL_MAC_PARAM_IV, iv, 12), OSSL_PARAM_construct_end() };
        EVP_MAC_init(m->ctx, NULL, 0, ps);
    } else if (m->poly) {           /* Poly1305 keys are one-time: a fresh key per message */
        unsigned char k[32]; memcpy(k, key, 32); memcpy(k, &nonce, 8);
        if (!EVP_MAC_init(m->ctx, k, 32, NULL)) { fprintf(stderr, "poly init\n"); exit(1); }
    } else if (!EVP_MAC_init(m->ctx, NULL, 0, NULL)) { fprintf(stderr, "reinit failed\n"); exit(1); }
    EVP_MAC_update(m->ctx, msg, len); EVP_MAC_final(m->ctx, out, &ol, 64); return ol;
}
/* One authentication of one vector by scheme sch; returns the tag size in bytes. */
static size_t run_once(int sch, const uint64_t *x, const double *xd, double *dd, size_t m, uint64_t nonce,
                       macctx *hm, macctx *cm, macctx *gm, macctx *pm, unsigned char *out, volatile uint64_t *sink) {
    switch (sch) {
    case 0: *sink ^= polytag_vec(x, m, nonce); return 8;
    case 1: rpvdvm_vec(xd, dd, m, nonce); rp_sink += dd[m-1]; return 8*m;
    case 2: return mac_run(hm, (const unsigned char*)x, m*8, out, nonce);
    case 3: return mac_run(cm, (const unsigned char*)x, m*8, out, nonce);
    case 4: return mac_run(gm, (const unsigned char*)x, m*8, out, nonce);
    default: return mac_run(pm, (const unsigned char*)x, m*8, out, nonce);
    }
}

int main(void) {
    platform_setup();
    report_cpu();
    aes = EVP_CIPHER_CTX_new(); EVP_EncryptInit_ex(aes, EVP_aes_128_ecb(), NULL, key, NULL);
    EVP_CIPHER_CTX_set_padding(aes, 0);
    size_t ms[4] = {108, 224, 980, 2244}; int R = 2001; double t[2001];
    printf("m,scheme,median_ns_per_vector,tag_bytes\n");
    for (int a = 0; a < 4; a++) {
        size_t m = ms[a];
        uint64_t *x = malloc(m*8); double *xd = malloc(m*8), *dd = malloc(m*8);
        for (size_t i = 0; i < m; i++) { xd[i] = (rand() % 200000 - 100000) / 100.0; x[i] = (uint64_t)(rand()) % PT_P; }
        unsigned char out[64]; volatile uint64_t sink = 0;
        macctx hm = mac_new("HMAC", "SHA256", NULL, 32), cm = mac_new("CMAC", NULL, "AES-128-CBC", 16),
               gm = mac_new("GMAC", NULL, "AES-128-GCM", 16), pm = mac_new("POLY1305", NULL, NULL, 32);
        const char *names[6] = {"PolyTag","RP-VDVM","HMAC-SHA256","AES128-CMAC","AES128-GMAC","Poly1305"};
        for (int sch = 0; sch < 6; sch++) {
            size_t tb = 8;
            int K = 1;
#ifdef _WIN32
            {   /* calibrate K so that one sample lasts >= 20 us */
                double c0 = now_ns();
                for (int j = 0; j < 200; j++) tb = run_once(sch, x, xd, dd, m, (1ULL << 40) + (uint64_t)j, &hm, &cm, &gm, &pm, out, &sink);
                double est = (now_ns() - c0) / 200.0;
                K = (int)(20000.0 / (est > 1 ? est : 1)) + 1; if (K > 2000) K = 2000;
            }
#endif
            for (int rep = 0; rep < R; rep++) {
                double t0 = now_ns();
                for (int j = 0; j < K; j++)
                    tb = run_once(sch, x, xd, dd, m, (uint64_t)rep * K + j, &hm, &cm, &gm, &pm, out, &sink);
                t[rep] = (now_ns() - t0) / K;
            }
            fprintf(stderr, "m=%zu %s: K=%d run(s) per sample\n", m, names[sch], K);
            qsort(t, R, sizeof(double), cmpd);
            printf("%zu,%s,%.0f,%zu\n", m, names[sch], t[R/2], sch == 1 ? 8*m : tb);
        }
        free(x); free(xd); free(dd);
        (void)sink;
    }
    return 0;
}

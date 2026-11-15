# PolyTag — reproduction code

Code for "From Dummy Variables to Provable Integrity: Bandwidth-Efficient
Authentication, Localization, and Correction of False Data Injection Attacks
in Smart Grids".

Every table and figure with data in the paper can be regenerated from this package. The section,
table and figure numbers below refer to the final version of the paper.

## Test platform

All results in the paper were produced on the following platforms (paper, Section IX):

| Item | Value |
| --- | --- |
| Machine | HP laptop, Intel Core i7-1255U (2 performance and 8 efficiency cores), Windows 11 |
| Simulations | MATLAB R2024a with MATPOWER 8.1 |
| C benchmarks | MinGW-w64 GCC 13, `-O2 -march=alderlake` (what `-march=native` selects on the i7-1255U), static OpenSSL 3.0.15; one performance core, high priority |
| Embedded benchmark | Particle Photon 2 (Realtek RTL8721DM, Arm Cortex-M33, 200 MHz), Device OS 6.4.1, GCC 10.2.1 `-Os`, mbedTLS 3.6.2 |

The platform of every run is recorded next to its results:

- `run_all` calls `platform_info`, which writes `results/00_platform.txt`
  (detected CPU, OS, MATLAB and MATPOWER versions, date).
- `c/bench.exe` and `c/correction127.exe` write the detected CPU and core type to
  `results/12_bench_platform.txt` and `results/13_correction_c_platform.txt`.
- The Photon 2 firmware prints its Device OS, compiler and timing method at start-up
  (`results/13_photon2_bench_log.txt`).

Timings (Table 8, Fig. 5, the solve times in Table 9, the SVM times in Table 11 and the
correction times in Table 12) depend on the processor.

## Requirements

**MATLAB** (R2019b or later; the paper used R2024a)
- Optimization Toolbox (`intlinprog`, used by run_08_protection)
- Statistics and Machine Learning Toolbox (`chi2inv`, `prctile`)
- MATPOWER 8.1 or later
- Java enabled (default), used by `hmac_sha256` in run_11

**GNU Octave** 8.4 also runs the scripts (the `statistics` package is needed; run_08 uses the
built-in `glpk` there), but all results in the paper come from MATLAB.

**C programs** (only to rebuild them; Windows executables are included): GCC or Clang with
OpenSSL 3 development files (Linux, macOS, or MSYS2/MinGW-w64 on Windows). MSVC is not supported
(`__int128`, `cpuid.h`).

**Figures in Python** (optional): Python 3 with matplotlib, for `plots/`.

## Run

1. Install MATPOWER and edit `setup_paths.m` so that `root` points to it.
2. In MATLAB, change to this folder and run `run_all`. The data sets are written to `data/`, the
   results (CSV) to `results/`, and the processor of the run to `results/00_platform.txt`.
   This runs run_01 to run_13; on the reference laptop the whole set took well under an hour.
3. Single experiments: `run_one('run_05_single_point')` and so on (run_01_datasets must have
   been run first, so that `data/` exists).
4. C timing benchmark (Section X-F, Table 8, Fig. 5): double-click `c/run_bench.bat`. It writes
   `results/12_bench.csv` and `results/12_bench_platform.txt`.
5. Correction in C (Section X-J, Table 12): after run_13_correction, double-click
   `c/run_correction.bat`. It writes `results/13_correction_c.csv` and
   `results/13_correction_c_platform.txt`.
6. Figures: run `make_figures` in MATLAB. It writes Figs. 2-6 to `figures/` (PDF and PNG) and
   prints every plotted value, for comparison with the paper.
7. Embedded benchmark (optional, needs a Photon 2 microcontroller): see `photon2/polytag_photon2/README.md`.

If Windows SmartScreen warns about the `.exe` files, choose "More info" > "Run anyway".

### C programs on Linux / WSL
From `c/`:

    gcc -O2 -march=native -o bench bench.c -lcrypto
    ./bench > ../results/12_bench.csv 2> ../results/12_bench_platform.txt
    gcc -O2 -march=native -o correction127 correction127.c -lcrypto
    ./correction127 > ../results/13_correction_c.csv 2> ../results/13_correction_c_platform.txt

(`bash run_bench.sh` installs the compiler and OpenSSL and runs the first two lines.)

The Windows executables were cross-compiled with MinGW-w64 GCC 13 against a static OpenSSL 3.0.15
(assembly enabled: AES-NI, PCLMULQDQ/AVX GHASH), for example

    x86_64-w64-mingw32-gcc -O2 -march=alderlake -D__USE_MINGW_ANSI_STDIO=1 -static -o bench.exe bench.c -lcrypto -lws2_32 -lgdi32 -lcrypt32 -luser32 -ladvapi32

On Windows both programs pin themselves to logical CPU 0 (a performance core on the i7-1255U)
and run at high priority. Because the Windows timer ticks every 100 ns, each of the 2,001
samples times K consecutive runs (K chosen so that a sample lasts at least 20 us) and the median
of the per-run means is reported; K and the core type are written to the platform file.

### Key-compromise ILP and time limits
As stated in the paper (Section X-G), `run_one` limits the cutting-plane loop of
run_08_protection to 240 s and each `intlinprog` solve to 60 s; the loop limit was not reached
in the reported run. To remove both limits, run in MATLAB:

    tlimit = Inf; solve_tlimit = Inf; run_08_protection

The status column of `results/08_protection.csv` reports `optimal` only when the lower and upper
bounds are equal. The lower bound stays valid even if a solve stops early, because it is taken
from the solver's proven bound.

## Scripts, result files and the paper

| Script | Result file | Paper |
| --- | --- | --- |
| run_01_datasets | data/*.mat (one year of hourly AC power flows per system) | Section IX, power system data (all 35,040 power flows converged) |
| run_02_detection | results/02_detection.csv | Section X-A, Table 4 |
| run_03_noise_fp | results/03_noise_fp.csv | Section X-C, Table 6 (WLS-BDD, RP-VDVM, PolyTag false positives) |
| run_04_rp32_calibrated | results/04_rp32_calibrated.csv | Section X-C, Table 6 (eta for 1% false positives) |
| run_05_single_point | results/05_single_point.csv | Section X-B, Table 5, Fig. 2(a), (b) |
| run_06_forgery | results/06_forgery.csv | Section X-D, Fig. 3 |
| run_07_localization | results/07_localization.csv | Section X-E, Table 7, Fig. 4; group-testing curve of Fig. 6 |
| run_08_protection | results/08_protection.csv | Section X-G, Table 9 |
| run_08d_leafcheck | results/08d_leafcheck.csv | Section VIII and X-G (degree-1 buses, k = 2 infeasibility) |
| run_09_svm | results/09_svm.csv | Section X-I, Table 11 |
| run_10_adaptive | results/10_adaptive.csv | Section X-H, Table 10 |
| run_11_coeff_generator | results/11_coeff_generator.csv | Section IV, implementation pitfall |
| run_12_delta_sweep | results/12_delta_sweep.csv | Section X-B, Fig. 2(c) |
| run_13_correction | results/13_correction.csv, results/13_tag127_test.txt | Section X-J, Table 12 (outcome counts) |
| c/bench.c (`bench.exe`, `run_bench.bat`) | results/12_bench.csv, results/12_bench_platform.txt | Section X-F, Table 8 (laptop), Fig. 5 |
| c/correction127.c (`correction127.exe`, `run_correction.bat`) | results/13_correction_c.csv, results/13_correction_c_platform.txt | Section X-J, Table 12 (times), 16,032-decode check |
| photon2/polytag_photon2 (Particle Photon 2) | results/13_photon2_bench.csv, results/13_photon2_bench_log.txt | Section X-F, Table 8 (microcontroller) |
| make_figures.m | figures/*.pdf, figures/*.png | Figs. 2-6 |

Tables 1 (abbreviations) and 3 (attack suite) contain no data. Table 2 (bandwidth) follows from
m = 2n + 4L of the MATPOWER case files. Fig. 1 is a TikZ drawing in the paper's LaTeX sources
(`Fig1_PolyTag_architecture.tex`). The byte counts of the keyed syndromes (32d), CCMAC-EC
(16d^2 + 8d) and RP-VDVM (8m) in Fig. 6 are formulas from Section X-J; only its group-testing
curve comes from a result file.

Other files:
- `run_all` runs run_01 to run_13 in order through `run_one`; `run_tail` re-runs run_09 to run_11.
- `run_08c` re-runs the 300-bus case for k = 1, 2 with a 200 s limit; it is not used in the paper.
- `plots/make_figs.py` and `plots/make_fig6.py` (Python 3, matplotlib) produced the figure files
  used in the paper from the same result files; `make_figures.m` is the MATLAB equivalent.
- `test_field`, `test_tag` and `c/test_vec.c` cross-check the GF(2^61 - 1) arithmetic and the
  tags between MATLAB and C; `correction127` cross-checks the GF(2^127 - 1) tags of run_13.

## Core functions
- `pt_P, pt_reduce, pt_mulmod, pt_addmod`: exact arithmetic in GF(2^61 - 1) with uint64.
- `pt_quantize, pt_tag, pt_tag_subsets, pt_randfield`: PolyTag encoding, tags, group-testing tags.
- `f127/f127_*`: arithmetic in GF(2^127 - 1) with 32-bit limbs in uint64 (mul, add, sub, neg,
  inv, conversion, random elements).
- `f127/corr_*`: keyed-syndrome tags (Eq. (9)), power tables, Berlekamp-Massey, root search,
  Vandermonde solve and fail-safe acceptance (`corr_decode`).
- `rp_dummy, rp32_relres`: RP-VDVM baseline (Eq. (17) of the RP-VDVM paper) and its float32 residual.
- `gen_dataset, meas_model, seasonal_profiles, dc_model`: power-system data and Jacobians.
- `robust_check`: robust observability test used by the ILP.
- `platform_info`: records the processor and software versions of a run.
- `c/polytag.h`: C reference implementation of PolyTag.

## Modelling notes
- In the MATLAB simulations the PRF is modelled as a random function (as in Lemma 1 and
  Theorem 1). The C programs and the Photon 2 firmware derive the keys with AES-128 (PolyTag:
  one block per vector; correction: 2d + 1 blocks, r = 0 rejected).
- Load profiles: the hourly seasonal bands of the RP-VDVM data generator. P and Q loads are both
  scaled, and dispatchable generation follows the mean factor.
- Noise: per-measurement Gaussian, sigma_i = 10^(-SNR/20) * max(|z_i|, 1 MW).
- WLS-BDD is the chi-square test (alpha = 0.01) on the WLS problem linearized at the true state.
- Simple FDI attacks (run_02) use the same 1,000 snapshots per system at 30 dB SNR as the stealth attacks.
- run_12 uses the same random draws as run_05, so Fig. 2(c) and Fig. 2(a), (b) share the
  attack vectors; its delta = 0.01 rows equal run_05.
- Correction (run_13): 300 vectors per system at 30 dB SNR, delta = 0.01 MW, GF(2^127 - 1),
  changes of 0.01-10 MW on randomly chosen entries, fresh keys for every vector and scenario.

## Provenance of the released results
- All simulation results (results/02 to 13) come from the MATLAB R2024a run on the reference
  laptop (results/00_platform.txt).
- results/08d_leafcheck.csv was produced by an earlier GNU Octave run. Its content (number of
  degree-1 buses and the rank test) is deterministic; `run_one('run_08d_leafcheck')` regenerates
  it in MATLAB.
- results/08c.log and results/tail.log are logs of that earlier Octave run and are kept for
  reference only; they are not used in the paper.
- The C timings and the Photon 2 timings were measured on the platforms recorded in their
  platform files.

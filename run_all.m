%RUN_ALL  Reproduce every result of the PolyTag paper (Octave 8 / MATLAB + MATPOWER).
%   Reference platform (paper, Section IX): HP laptop, Intel Core i7-1255U (10 cores),
%   GNU Octave 8.4.0/MATLAB 2019b or later, MATPOWER 8.1.1-dev. The CPU actually used is
%   recorded in results/00_platform.txt by platform_info (called from run_all).
RUNALL = {'run_01_datasets','run_02_detection','run_03_noise_fp','run_04_rp32_calibrated', ...
          'run_05_single_point','run_06_forgery','run_07_localization','run_08_protection', ...
          'run_09_svm','run_10_adaptive','run_11_coeff_generator', 'run_12_delta_sweep', 'run_13_correction'};
setup_paths;   % also creates results/ and data/ in the current folder
platform_info('results/00_platform.txt');   % records the CPU actually used
if ~exist('RUNALL_from', 'var'), RUNALL_from = 1; end
for RUNALL_i = RUNALL_from:numel(RUNALL), run_one(RUNALL{RUNALL_i}); end

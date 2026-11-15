%RUN_08C  300-bus k = 1, 2 rerun of run_08_protection (time limit 200 s).
%   Reference platform (paper, Section IX): HP laptop, Intel Core i7-1255U (10 cores),
%   GNU Octave 8.4.0, MATPOWER 8.1.1-dev. The CPU actually used is
%   recorded in results/00_platform.txt by platform_info (called from run_all).
setup_paths; cases={'case300'}; csvmode='a'; tlimit=200; klist=[1 2]; run_08_protection;

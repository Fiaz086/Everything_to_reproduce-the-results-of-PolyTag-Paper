%RUN_01_DATASETS  Generate one year of hourly snapshots for each test system.
%   Reference platform (paper, Section IX): HP laptop, Intel Core i7-1255U (10 cores),
%   GNU Octave 8.4.0, MATPOWER 8.1.1-dev. The CPU actually used is
%   recorded in results/00_platform.txt by platform_info (called from run_all).
setup_paths;
cases = {'case14','case30','case118','case300'};
for c = 1:numel(cases)
  tic; D = gen_dataset(cases{c}, 365, c);
  fprintf('%-8s n=%3d L=%3d m=%4d  converged %d/%d  (%.0f s)\n', cases{c}, D.n, D.L, D.m, sum(D.ok), numel(D.ok), toc);
  if exist(fullfile(pwd, 'data'), 'dir') ~= 7, mkdir(fullfile(pwd, 'data')); end
  save(fullfile(pwd, 'data', [cases{c} '.mat']), 'D', '-v7');
end

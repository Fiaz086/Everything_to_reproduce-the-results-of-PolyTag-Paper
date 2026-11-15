%RUN_ONE  
%   Reference platform (paper, Section IX): HP laptop, Intel Core i7-1255U (10 cores),
%   GNU Octave 8.4.0/MATLAB 2019b or later, MATPOWER 8.1.1-dev. The CPU actually used is
%   recorded in results/00_platform.txt by platform_info (called from run_all).
function run_one(RUNONE_name)
%RUN_ONE  Run one experiment script in its own workspace (no variable clashes).
setup_paths;
if strcmp(RUNONE_name, 'run_08_protection'), tlimit = 240; end %#ok used by the script
RUNONE_t0 = tic; fprintf('=== %s ===\n', RUNONE_name);
eval(RUNONE_name);
fprintf('=== %s done in %.0f s ===\n', RUNONE_name, toc(RUNONE_t0));
end

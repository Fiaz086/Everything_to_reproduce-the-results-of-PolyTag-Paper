%RUN_08D_LEAFCHECK  Direct infeasibility proof for k = 2 (bus devices): for every
%   bus i of degree 1 with neighbour j, compromising {i, j} removes all rows that
%   involve the angle of i, so rank(H_{all \ {i,j}}) < n-1 for any protection set.
%   Reference platform (paper, Section IX): HP laptop, Intel Core i7-1255U (10 cores),
%   GNU Octave 8.4.0, MATPOWER 8.1.1-dev. The CPU actually used is
%   recorded in results/00_platform.txt by platform_info (called from run_all).
setup_paths; define_constants;
cases = {'case14','case30','case118','case300'};
fid = fopen('results/08d_leafcheck.csv', 'w');
fprintf(fid, 'system,degree1_buses,example_pair,rank_without_pair,n_states\n');
for c = 1:numel(cases)
  [H, own, N] = dc_model(cases{c}); nx = size(H, 2);
  mpc = ext2int(loadcase(cases{c})); f = mpc.branch(:, F_BUS); t = mpc.branch(:, T_BUS);
  deg = accumarray([f; t], 1, [N 1]); leaves = find(deg == 1);
  i = leaves(1); br = find(f == i | t == i); j = setdiff([f(br) t(br)], i);
  keep = ~ismember(own, [i j]);
  r = rank(full(H(keep, :)));
  ext = mpc.order.bus.i2e;                   % report external bus numbers
  fprintf(fid, '%s,%d,"%d-%d",%d,%d\n', cases{c}, numel(leaves), ext(i), ext(j), r, nx);
  fprintf('%s: %d degree-1 buses; compromising buses %d and %d leaves rank %d of %d\n', cases{c}, numel(leaves), ext(i), ext(j), r, nx);
end
fclose(fid);

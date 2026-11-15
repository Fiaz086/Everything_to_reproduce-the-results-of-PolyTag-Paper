%RUN_07_LOCALIZATION  Group-testing localization of tampered measurements.
%   Real PolyTags over the rows of a design matrix M; the attacker changes d
%   measurements of a real (noisy) measurement vector; the control centre
%   verifies all T tags and decodes with COMP (an index is cleared if it lies
%   in at least one passing tag).
%   Reference platform (paper, Section IX): HP laptop, Intel Core i7-1255U (10 cores),
%   GNU Octave 8.4.0, MATPOWER 8.1.1-dev. The CPU actually used is
%   recorded in results/00_platform.txt by platform_info (called from run_all).
setup_paths;
cases = {'case118','case300'}; K = 300; SNR = 30; delta = 0.01;
grid = {1, [10 15 20 30 40]; 2, [30 45 60 90 120]; 3, [60 90 120 180 240]};
fid = fopen('results/07_localization.csv', 'w');
fprintf(fid, 'system,m,design,d,T,overhead_bytes,exact_recovery,precision,recall,flagged_mean\n');
for c = 1:numel(cases)
  load(fullfile(pwd, 'data', [cases{c} '.mat'])); m = D.m;
  rng(700 + c);
  ks = randperm(size(D.Z, 2), K);
  Zm = D.Z(:, ks) + 10^(-SNR/20) * max(abs(D.Z(:, ks)), 1) .* randn(m, K);
  q = pt_quantize(Zm, delta);
  designs = {};
  % binary-code design for d = 1: column i = binary code of i (nonzero), plus all-ones row
  b = ceil(log2(m + 1)); Mb = zeros(b + 1, m);
  for i = 1:m, Mb(1:b, i) = bitget(i, 1:b)'; end
  Mb(b + 1, :) = 1;
  designs(end+1, :) = {'binary', 1, Mb};
  for g = 1:size(grid, 1)
    d = grid{g, 1};
    for T = grid{g, 2}
      Mr = rand(T, m) < 1/(d + 1);
      designs(end+1, :) = {'random', d, Mr}; %#ok
    end
  end
  for t = 1:size(designs, 1)
    [name, d, M] = designs{t, :}; T = size(M, 1);
    r = pt_randfield(T, K); s = pt_randfield(T, K);
    tau = pt_tag_subsets(q, M, r, s);
    % attack d distinct measurements of each vector by a nonzero integer offset
    qa = q; A = false(m, K);
    for k = 1:K
      idx = randperm(m, d); A(idx, k) = true;
      off = uint64(randi([1 1000], d, 1));          % 0.01 .. 10 MW
      qa(idx, k) = pt_addmod(q(idx, k), off);
    end
    pass = pt_tag_subsets(qa, M, r, s) == tau;      % T x K
    if strcmp(name, 'binary')
      % codeword decoder: failing rows 1..b spell the index of the tampered measurement
      fail = ~pass; b = T - 1; flagged = false(m, K);
      idx = (2.^(0:b-1)) * double(fail(1:b, :));
      okk = fail(T, :) & idx >= 1 & idx <= m;
      flagged(sub2ind([m K], idx(okk), find(okk))) = true;
    else
      cleared = (double(M') * double(pass)) > 0;    % COMP decoder, m x K
      flagged = ~cleared;
    end
    tp = sum(flagged & A); fp = sum(flagged & ~A);
    exact = mean(all(flagged == A, 1));
    prec = mean(tp ./ max(tp + fp, 1)); rec = mean(tp ./ d);
    fprintf(fid, '%s,%d,%s,%d,%d,%d,%.4f,%.4f,%.4f,%.2f\n', cases{c}, m, name, d, T, 8*T, exact, prec, rec, mean(sum(flagged)));
    fprintf('%s %-6s d=%d T=%3d (%4d B): exact %.3f  precision %.3f  recall %.3f  flagged %.1f\n', cases{c}, name, d, T, 8*T, exact, prec, rec, mean(sum(flagged)));
  end
  clear D
end
fclose(fid);

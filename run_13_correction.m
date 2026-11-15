%RUN_13_CORRECTION  Keyed-syndrome localization and correction (Section VII-B, Section X-J, Table 12).
%   300 measurement vectors per system (IEEE 118- and 300-bus, 30 dB SNR, delta = 0.01 MW), field
%   GF(2^127 - 1), d = 1, 2, 3, 5 and six scenarios: honest, d changed entries, d + 1 changed
%   entries, 2d changed entries, one altered tag, and d changed entries with one altered tag.
%   Changes of 0.01-10 MW (uniform magnitude, random sign) are applied to randomly chosen entries.
%   Keys r (nonzero) and s_1..s_2d are fresh for every vector and scenario; as in Theorem 1, the
%   PRF is modelled as a random function (the C implementation derives them with AES-128).
%   Decoding: syndromes (Eq. (10)), Berlekamp-Massey, root search over the m positions,
%   Vandermonde solve, and fail-safe acceptance (all 2d syndromes must be reproduced).
%   Output: results/13_correction.csv (counts per system, d and scenario) and
%   results/13_tag127_test.txt (test vectors for the C implementation).
%   Reference platform (paper, Section IX): HP laptop, Intel Core i7-1255U, MATLAB R2024a.
setup_paths; addpath(fullfile(pwd, 'f127'));
cases = {'case118', 'case300'}; ds = [1 2 3 5]; N = 300; SNR = 30; delta = 0.01;
scen = {'honest', 'd_changed', 'd_plus_1_changed', '2d_changed', 'tag_altered', 'd_changed_tag_altered'};
fid = fopen(fullfile(pwd, 'results', '13_correction.csv'), 'w');
fprintf(fid, 'system,m,d,scenario,vectors,accepted_correct,rejected,wrong_accepted,seconds\n');
for c = 1:numel(cases)
  load(fullfile(pwd, 'data', [cases{c} '.mat'])); m = D.m;
  rng(1300 + c, 'twister');
  kk = randperm(size(D.Z, 2), N);
  Z = D.Z(:, kk) + 10^(-SNR/20) * max(abs(D.Z(:, kk)), 1) .* randn(m, N);
  Zq = round(Z / delta);                          % quantized integers, |Zq| < 2^53
  F = f127_from_int(Zq(:));
  for d = ds
    for sc = 1:numel(scen)
      t0 = tic;
      r = f127_rand(N, true); s = zeros(N, 4, 2*d, 'uint64');
      for l = 1:2*d, s(:, :, l) = f127_rand(N); end
      X = corr_powtable(r, m); Y = corr_powtable(f127_inv(r), m);
      tau = corr_tags(F, X, s, m, N, d);
      % --- adversary
      switch scen{sc}
        case {'honest', 'tag_altered'}, k = 0;
        case {'d_changed', 'd_changed_tag_altered'}, k = d;
        case 'd_plus_1_changed', k = d + 1;
        case '2d_changed', k = 2*d;
      end
      Zh = Zq;
      for n = 1:N
        if k > 0
          T = randperm(m, k);
          mag = round((0.01 + (10 - 0.01) * rand(k, 1)) / delta);   % 0.01-10 MW, >= 1 step
          Zh(T, n) = Zh(T, n) + mag .* (2 * (rand(k, 1) > 0.5) - 1);
        end
      end
      tauh = tau;
      if any(strcmp(scen{sc}, {'tag_altered', 'd_changed_tag_altered'}))
        for n = 1:N, l = randi(2*d); tauh(n, :, l) = f127_add(tauh(n, :, l), f127_rand(1, true)); end
      end
      % --- control center: syndromes and decoding
      Fh = f127_from_int(Zh(:)); Xl = X; S = zeros(N, 4, 2*d, 'uint64');
      for l = 1:2*d
        if l > 1, Xl = f127_mul(Xl, X); end
        S(:, :, l) = f127_sub(corr_wsum(Fh, Xl, m, N), f127_sub(tauh(:, :, l), s(:, :, l)));
      end
      [st, pos, val] = corr_decode(S, X, Y, m, N, d);
      % --- outcome: accepted vector equal to the transmitted one, rejected, or wrong acceptance
      good = 0; wrong = 0;
      for n = 1:N
        rows = (n-1)*m + (1:m);
        if st(n) == 1, acc = Fh(rows, :);
        elseif st(n) == 2, acc = Fh(rows, :); acc(pos{n}, :) = f127_sub(acc(pos{n}, :), val{n});
        else, continue; end
        if isequal(acc, F(rows, :)), good = good + 1; else, wrong = wrong + 1; end
      end
      sec = toc(t0);
      fprintf(fid, '%s,%d,%d,%s,%d,%d,%d,%d,%.1f\n', cases{c}, m, d, scen{sc}, N, good, sum(st == 0), wrong, sec);
      fprintf('%s d=%d %-22s accepted-correct %3d  rejected %3d  wrong %d  (%.0f s)\n', cases{c}, d, scen{sc}, good, sum(st == 0), wrong, sec);
      % --- test vectors for the C implementation (300-bus, d = 2, honest scenario, 3 vectors)
      if strcmp(cases{c}, 'case300') && d == 2 && sc == 1
        ft = fopen(fullfile(pwd, 'results', '13_tag127_test.txt'), 'w');
        for n = 1:3
          fprintf(ft, '%d %d %s', d, m, f127_hex(r(n, :)));
          for l = 1:2*d, fprintf(ft, ' %s', f127_hex(s(n, :, l))); end
          for l = 1:2*d, fprintf(ft, ' %s', f127_hex(tau(n, :, l))); end
          fprintf(ft, ' %d', Zq(:, n)); fprintf(ft, '\n');
        end
        fclose(ft);
      end
    end
  end
  clear D
end
fclose(fid);

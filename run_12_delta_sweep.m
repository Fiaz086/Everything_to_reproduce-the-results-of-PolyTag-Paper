%RUN_12_DELTA_SWEEP  Fig. 2(c): effect of the quantization step delta on single-measurement attacks.
%   Repeats run_05_single_point with the same random draws (same seeds, same call order), so the
%   attack vectors, keys and RP-VDVM results are identical to run_05; only the PolyTag step delta
%   varies (0.001, 0.01 and 0.1 MW/Mvar). For each delta it records the share of attacks that alter
%   the transmitted quantized vector, the detection rate among those, and the rejection rate of the
%   honest vectors.
%   Reference platform (paper, Section IX): HP laptop, Intel Core i7-1255U, MATLAB R2024a,
%   MATPOWER 8.1. The CPU actually used is recorded in results/00_platform.txt by platform_info.
setup_paths;
cases = {'case14','case30','case118','case300'};
epsl = [1e-6 1e-5 1e-4 1e-3 1e-2]; Ncal = 2000; N = 2000; SNR = 30;
deltas = [0.001 0.01 0.1];
fid = fopen(fullfile(pwd, 'results', '12_delta_sweep.csv'), 'w');
fprintf(fid, 'system,delta,rel_change,median_abs_change_MW,RP32naive_det,PT_changed_frac,PT_det_changed,PT_honest_rejected\n');
for c = 1:numel(cases)
  load(fullfile(pwd, 'data', [cases{c} '.mat'])); m = D.m;
  % ---- identical to run_05_single_point (same seed, same draws in the same order) ----
  rng(500 + c);
  perm = randperm(size(D.Z, 2)); kc = perm(1:Ncal); kt = perm(Ncal+1:Ncal+N);
  Zc = D.Z(:, kc) + 10^(-SNR/20) * max(abs(D.Z(:, kc)), 1) .* randn(m, Ncal);
  Cf = -5 + 10 * rand(6, m, Ncal);
  eta = prctile(rp32_relres(double(single(rp_dummy(Zc, Cf))), Zc, Cf), 99);
  Zm = D.Z(:, kt) + 10^(-SNR/20) * max(abs(D.Z(:, kt)), 1) .* randn(m, N);
  Cf = -5 + 10 * rand(6, m, N);
  d32 = double(single(rp_dummy(Zm, Cf)));
  r = pt_randfield(1, N); s = pt_randfield(1, N);
  idx = zeros(1, N);
  for j = 1:N, cand = find(abs(Zm(:, j)) >= 1); idx(j) = cand(randi(numel(cand))); end
  lin = sub2ind([m N], idx, 1:N);
  % ---- delta sweep ----
  for dl = deltas
    q = pt_quantize(Zm, dl); tau = pt_tag(q, r, s);
    honest_rej = mean(pt_tag(q, r, s) ~= tau);
    for e = epsl
      Za = Zm; Za(lin) = Zm(lin) * (1 + e);
      det = mean(rp32_relres(d32, Za, Cf) > eta);
      qa = pt_quantize(Za, dl); ch = any(qa ~= q, 1); ok = pt_tag(qa, r, s) == tau;
      if any(ch), detch = mean(~ok(ch)); else, detch = NaN; end
      fprintf(fid, '%s,%g,%g,%.4g,%.4f,%.4f,%.4f,%.4f\n', cases{c}, dl, e, median(abs(Zm(lin))*e), det, mean(ch), detch, honest_rej);
      fprintf('%s delta=%g eps=%g RP32naive %.3f PT changed %.3f det %.4f\n', cases{c}, dl, e, det, mean(ch), detch);
    end
  end
  clear D
end
fclose(fid);

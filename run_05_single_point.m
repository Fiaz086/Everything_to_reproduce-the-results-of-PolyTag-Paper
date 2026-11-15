%RUN_05_SINGLE_POINT  Targeted attack on ONE measurement: x_i <- x_i*(1+eps).
%   RP-VDVM (float32 transport, eta calibrated to 1% FP as in run_04) vs PolyTag.
%   Reference platform (paper, Section IX): HP laptop, Intel Core i7-1255U (10 cores),
%   GNU Octave 8.4.0, MATPOWER 8.1.1-dev. The CPU actually used is
%   recorded in results/00_platform.txt by platform_info (called from run_all).
setup_paths;
cases = {'case14','case30','case118','case300'};
epsl = [1e-6 1e-5 1e-4 1e-3 1e-2]; Ncal = 2000; N = 2000; SNR = 30; delta = 0.01;
fid = fopen('results/05_single_point.csv', 'w');
fprintf(fid, 'system,eta,rel_change,median_abs_change_MW,RP32naive_det,PT_changed_frac,PT_det_changed\n');
for c = 1:numel(cases)
  load(fullfile(pwd, 'data', [cases{c} '.mat'])); m = D.m;
  rng(500 + c);
  perm = randperm(size(D.Z, 2)); kc = perm(1:Ncal); kt = perm(Ncal+1:Ncal+N);
  Zc = D.Z(:, kc) + 10^(-SNR/20) * max(abs(D.Z(:, kc)), 1) .* randn(m, Ncal);
  Cf = -5 + 10 * rand(6, m, Ncal);
  eta = prctile(rp32_relres(double(single(rp_dummy(Zc, Cf))), Zc, Cf), 99);
  Zm = D.Z(:, kt) + 10^(-SNR/20) * max(abs(D.Z(:, kt)), 1) .* randn(m, N);
  Cf = -5 + 10 * rand(6, m, N);
  d32 = double(single(rp_dummy(Zm, Cf)));
  q = pt_quantize(Zm, delta); r = pt_randfield(1, N); s = pt_randfield(1, N); tau = pt_tag(q, r, s);
  % target: one random measurement with |x| >= 1 MW per vector
  idx = zeros(1, N);
  for j = 1:N, cand = find(abs(Zm(:, j)) >= 1); idx(j) = cand(randi(numel(cand))); end
  lin = sub2ind([m N], idx, 1:N);
  for e = epsl
    Za = Zm; Za(lin) = Zm(lin) * (1 + e);
    det = mean(rp32_relres(d32, Za, Cf) > eta);
    qa = pt_quantize(Za, delta); ch = any(qa ~= q, 1); ok = pt_tag(qa, r, s) == tau;
    fprintf(fid, '%s,%.4g,%g,%.4g,%.4f,%.4f,%.4f\n', cases{c}, eta, e, median(abs(Zm(lin))*e), det, mean(ch), mean(~ok(ch)));
    fprintf('%s eta=%.3g eps=%g |dx|~%.3g MW RP32naive %.3f PT changed %.3f det %.4f\n', cases{c}, eta, e, median(abs(Zm(lin))*e), det, mean(ch), mean(~ok(ch)));
  end
  clear D
end
fclose(fid);

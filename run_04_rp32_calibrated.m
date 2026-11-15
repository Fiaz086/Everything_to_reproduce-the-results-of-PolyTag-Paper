%RUN_04_RP32_CALIBRATED  RP-VDVM with float32 transport (dummy computed on the
%   full-precision reading). The tolerance eta is calibrated on an independent
%   honest set to a 1% false-positive rate; detection of stealth attacks is then
%   measured on a separate test set. PolyTag on the same test set for reference.
%   Reference platform (paper, Section IX): HP laptop, Intel Core i7-1255U (10 cores),
%   GNU Octave 8.4.0, MATPOWER 8.1.1-dev. The CPU actually used is
%   recorded in results/00_platform.txt by platform_info (called from run_all).
setup_paths;
cases = {'case14','case30','case118','case300'};
sigc = [1e-7 1e-6 1e-5 1e-4 1e-3 1e-2]; Ncal = 2000; N = 1000; SNR = 30; delta = 0.01;
fid = fopen('results/04_rp32_calibrated.csv', 'w');
fprintf(fid, 'system,eta_at_1pct_fp,test_fp,sigma_c,median_ainf_MW,RP32naive_det,PT_det_changed,PT_changed_frac\n');
for c = 1:numel(cases)
  load(fullfile(pwd, 'data', [cases{c} '.mat'])); m = D.m; nx = 2*D.n - 1;
  rng(400 + c);
  perm = randperm(size(D.Z, 2)); kc = perm(1:Ncal); kt = perm(Ncal+1:Ncal+N);
  % calibration
  Zc = D.Z(:, kc) + 10^(-SNR/20) * max(abs(D.Z(:, kc)), 1) .* randn(m, Ncal);
  Cf_ = -5 + 10 * rand(6, m, Ncal);
  rc = rp32_relres(double(single(rp_dummy(Zc, Cf_))), Zc, Cf_);
  eta = prctile(rc, 99);
  % test set
  Zm = D.Z(:, kt) + 10^(-SNR/20) * max(abs(D.Z(:, kt)), 1) .* randn(m, N);
  Cf_ = -5 + 10 * rand(6, m, N);
  d32 = double(single(rp_dummy(Zm, Cf_)));
  fp = mean(rp32_relres(d32, Zm, Cf_) > eta);
  q = pt_quantize(Zm, delta); r = pt_randfield(1, N); s = pt_randfield(1, N); tau = pt_tag(q, r, s);
  Hs = cell(N, 1);
  for j = 1:N, [~, Hs{j}] = meas_model(D.Ybus, D.Yf, D.Yt, D.branch, D.V(:, kt(j)), D.ref, D.baseMVA); end
  for sc = sigc
    A = zeros(m, N); for j = 1:N, A(:, j) = Hs{j} * (sc * randn(nx, 1)); end
    Za = Zm + A;
    det = mean(rp32_relres(d32, Za, Cf_) > eta);
    qa = pt_quantize(Za, delta); ch = any(qa ~= q, 1); ok = pt_tag(qa, r, s) == tau;
    fprintf(fid, '%s,%.4g,%.4f,%g,%.4g,%.4f,%.4f,%.4f\n', cases{c}, eta, fp, sc, median(max(abs(A), [], 1)), det, mean(~ok(ch)), mean(ch));
    fprintf('%s eta=%.3g testfp=%.3f sc=%g |a|~%.3g MW RP32naive %.3f PT %.4f (changed %.3f)\n', cases{c}, eta, fp, sc, median(max(abs(A), [], 1)), det, mean(~ok(ch)), mean(ch));
  end
  clear D Hs
end
fclose(fid);

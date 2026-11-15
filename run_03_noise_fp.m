%RUN_03_NOISE_FP  False positives on honest data at SNR 10, 20, 30 dB.
%   RP32-best : meter computes the dummy on the float32 value it transmits.
%   RP32-naive: meter computes the dummy on its full-precision reading but
%               transmits float32 (common in DNP3/IEC 61850 analog points).
%   Reference platform (paper, Section IX): HP laptop, Intel Core i7-1255U (10 cores),
%   GNU Octave 8.4.0, MATPOWER 8.1.1-dev. The CPU actually used is
%   recorded in results/00_platform.txt by platform_info (called from run_all).
setup_paths; if exist('OCTAVE_VERSION','builtin'), pkg load statistics; end
cases = {'case14','case30','case118','case300'};
N = 2000; delta = 0.01; alpha = 0.01; etaS = 2^-23;
fid = fopen('results/03_noise_fp.csv', 'w');
fprintf(fid, 'system,SNR_dB,BDD_fp,RP64_fp,RP32best_fp,RP32naive_fp,RP32naive_relres_p99,RP32naive_relres_max,PT_fp\n');
for c = 1:numel(cases)
  load(fullfile(pwd, 'data', [cases{c} '.mat']));
  m = D.m; nx = 2*D.n - 1; thr = chi2inv(1 - alpha, m - nx);
  for SNR = [10 20 30]
    rng(300 + 10*c + SNR);
    ks = randperm(size(D.Z, 2), N);
    SG = 10^(-SNR/20) * max(abs(D.Z(:, ks)), 1);
    E = SG .* randn(m, N); Zm = D.Z(:, ks) + E;
    Cf = -5 + 10 * rand(6, m, N);
    % WLS BDD
    J = zeros(1, N);
    for j = 1:N
      [~, H] = meas_model(D.Ybus, D.Yf, D.Yt, D.branch, D.V(:, ks(j)), D.ref, D.baseMVA);
      W = 1 ./ SG(:, j).^2; R = chol(H' * spdiags(W, 0, m, m) * H);
      res = E(:, j) - H * (R \ (R' \ (H' * (W .* E(:, j)))));
      J(j) = sum(W .* res.^2);
    end
    % RP-VDVM
    rp64 = mean(any(rp_dummy(Zm, Cf) ~= rp_dummy(Zm, Cf), 1));       % same arithmetic both ends
    xs = double(single(Zm));
    Pcc = rp_dummy(xs, Cf);                                          % control-centre recomputation
    best  = double(single(rp_dummy(xs, Cf)));
    naive = double(single(rp_dummy(Zm, Cf)));
    rb = abs(best - Pcc) ./ max(abs(Pcc), realmin);
    rn = abs(naive - Pcc) ./ max(abs(Pcc), realmin);
    rnmax = max(rn, [], 1);
    % PolyTag
    q = pt_quantize(Zm, delta); r = pt_randfield(1, N); s = pt_randfield(1, N);
    tau = pt_tag(q, r, s); ptfp = mean(pt_tag(q, r, s) ~= tau);
    fprintf(fid, '%s,%d,%.4f,%.4f,%.4f,%.4f,%.3g,%.3g,%.4f\n', cases{c}, SNR, mean(J > thr), rp64, ...
      mean(any(rb > etaS, 1)), mean(any(rn > etaS, 1)), prctile(rnmax, 99), max(rnmax), ptfp);
    fprintf('%s SNR %d: BDD %.4f RP64 %.4f RP32best %.4f RP32naive %.4f (relres p99 %.3g max %.3g) PT %.4f\n', cases{c}, SNR, ...
      mean(J > thr), rp64, mean(any(rb > etaS, 1)), mean(any(rn > etaS, 1)), prctile(rnmax, 99), max(rnmax), ptfp);
  end
  clear D
end
fclose(fid);

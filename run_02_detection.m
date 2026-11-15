%RUN_02_DETECTION  Detection rate vs stealth-attack magnitude, and false positives.
%   For each test system: N random snapshots; Gaussian noise at a given SNR;
%   stealth attack a = H*c with c ~ N(0, sigma_c^2 I) on the AC states.
%   Detectors: linearized WLS chi-square BDD (alpha = 0.01), RP-VDVM with
%   64-bit and 32-bit float transport, and PolyTag (delta = 0.01 MW/Mvar).
%   Reference platform (paper, Section IX): HP laptop, Intel Core i7-1255U (10 cores),
%   GNU Octave 8.4.0, MATPOWER 8.1.1-dev. The CPU actually used is
%   recorded in results/00_platform.txt by platform_info (called from run_all).
setup_paths; if exist('OCTAVE_VERSION','builtin'), pkg load statistics; end
if ~exist('cases','var'), cases = {'case14','case30','case118','case300'}; end
sigc   = [1e-7 1e-6 1e-5 1e-4 1e-3 1e-2];
N      = 1000;          % attacked snapshots per (system, sigma_c)
SNR    = 30;            % dB, per-measurement
delta  = 0.01;          % quantization step (MW / Mvar)
alpha  = 0.01;
etaS   = 2^-23;         % RP-VDVM tolerance for 32-bit transport (2 x float32 rounding)
if ~exist('csvmode','var'), csvmode = 'w'; end
fid = fopen('results/02_detection.csv', csvmode);
if csvmode == 'w', fprintf(fid, 'system,attack,sigma_c,median_ainf_MW,BDD_det,BDD_fp,RP64_det,RP32_det,PT_changed_frac,PT_det_changed\n'); end
for c = 1:numel(cases)
  load(fullfile(pwd, 'data', [cases{c} '.mat']));     % -> D
  rng(100 + find(strcmp(cases{c}, {'case14','case30','case118','case300'})));
  m = D.m; nx = 2*D.n - 1; thr = chi2inv(1 - alpha, m - nx);
  ks = randperm(size(D.Z, 2), N);
  % precompute per-snapshot quantities shared by all attack levels
  Hs = cell(N,1); E = zeros(m, N); SG = zeros(m, N); Cf = zeros(6, m, N);  % RP-VDVM coefficients
  for j = 1:N
    k = ks(j);
    [~, Hs{j}] = meas_model(D.Ybus, D.Yf, D.Yt, D.branch, D.V(:,k), D.ref, D.baseMVA);
    SG(:, j) = 10^(-SNR/20) * max(abs(D.Z(:,k)), 1);
    E(:, j)  = SG(:, j) .* randn(m, 1);
    Cf(:, :, j) = -5 + 10 * rand(6, m);
  end
  Zm = D.Z(:, ks) + E;                           % what the meters measure
  % honest-side quantities
  q   = pt_quantize(Zm, delta);
  r   = pt_randfield(1, N); s = pt_randfield(1, N);
  tau = pt_tag(q, r, s);
  d64 = rp_dummy(Zm, Cf);
  xs  = double(single(Zm)); d32 = double(single(rp_dummy(xs, Cf)));
  Jh = zeros(1, N); Kmat = cell(N,1);
  for j = 1:N
    W = 1 ./ SG(:, j).^2; H = Hs{j};
    R = chol(H' * spdiags(W, 0, m, m) * H);     % G = H'WH (sparse)
    Kmat{j} = {R, W};
    res = E(:, j) - H * (R \ (R' \ (H' * (W .* E(:, j)))));
    Jh(j) = sum(W .* res.^2);
  end
  bdd_fp = mean(Jh > thr);
  for a_type = 1:2
    if a_type == 1, levels = sigc; else, levels = NaN; end
    for sc = levels
      A = zeros(m, N);
      for j = 1:N
        if a_type == 1
          A(:, j) = Hs{j} * (sc * randn(nx, 1));
        else   % simple attack: one random offset between 0.5% of min and 0.5% of max
          zz = Zm(:, j); lo = 0.005 * min(zz); hi = 0.005 * max(zz);
          A(:, j) = lo + rand * (hi - lo);
        end
      end
      Za = Zm + A;
      % WLS BDD (linearized at the true state)
      Ja = zeros(1, N);
      for j = 1:N
        R = Kmat{j}{1}; W = Kmat{j}{2}; H = Hs{j}; dz = E(:, j) + A(:, j);
        res = dz - H * (R \ (R' \ (H' * (W .* dz))));
        Ja(j) = sum(W .* res.^2);
      end
      bdd = mean(Ja > thr);
      % RP-VDVM: attacker changes measurements, cannot recompute dummies
      rp64 = mean(any(abs(d64 - rp_dummy(Za, Cf)) > 0, 1));
      xas  = double(single(Za)); P32 = rp_dummy(xas, Cf);
      rp32 = mean(any(abs(d32 - P32) > etaS * max(abs(P32), realmin), 1));
      % PolyTag: attacker rewrites the quantized values, keeps the tag
      qa = pt_quantize(Za, delta);
      changed = any(qa ~= q, 1);
      ok = pt_tag(qa, r, s) == tau;
      pt_det = mean(~ok(changed));
      fprintf(fid, '%s,%s,%g,%.4g,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n', cases{c}, ...
        ifelse_str(a_type==1,'stealth','simple'), sc, median(max(abs(A),[],1)), ...
        bdd, bdd_fp, rp64, rp32, mean(changed), pt_det);
      fprintf('%s %s sc=%g |a|inf~%.3g MW  BDD %.3f (fp %.3f)  RP64 %.3f  RP32 %.3f  PT changed %.3f det %.4f\n', ...
        cases{c}, ifelse_str(a_type==1,'stealth','simple'), sc, median(max(abs(A),[],1)), bdd, bdd_fp, rp64, rp32, mean(changed), pt_det);
    end
  end
  clear D Hs Kmat
end
fclose(fid);

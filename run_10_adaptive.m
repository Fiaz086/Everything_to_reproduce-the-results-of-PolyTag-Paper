%RUN_10_ADAPTIVE  Adaptive (regression) adversary vs NF-VDVM, RP-VDVM and PolyTag.
%   For one measurement, the adversary observes the (x, x') pairs of the previous
%   Nobs slots, fits a 5th-order polynomial by least squares, and then forges the
%   current slot: x_hat = 1.01 x with dummy x_hat' = fitted P(x_hat).
%   Acceptance tolerance (64-bit transport) eta = 1e-9 relative (lenient).
%   PolyTag: the adversary fits tau against the measurements of past slots and
%   submits the rounded prediction as the forged tag.
%   Reference platform (paper, Section IX): HP laptop, Intel Core i7-1255U (10 cores),
%   GNU Octave 8.4.0, MATPOWER 8.1.1-dev. The CPU actually used is
%   recorded in results/00_platform.txt by platform_info (called from run_all).
setup_paths;
cases = {'case14','case118'}; Nobs_list = [3 5 6 10 24 168]; trials = 500; eta = 1e-9; delta = 0.01;
fid = fopen('results/10_adaptive.csv', 'w');
fprintf(fid, 'system,N_observed,NF_VDVM_forgery_success,RP_VDVM_forgery_success,PolyTag_forgery_success\n');
for c = 1:numel(cases)
  load(fullfile(pwd, 'data', [cases{c} '.mat'])); m = D.m; T = size(D.Z, 2);
  for Nobs = Nobs_list
    rng(1000 + 10*c + Nobs); succ = [0 0 0];
    for tr = 1:trials
      i = randi(m); while max(abs(D.Z(i, :))) < 1, i = randi(m); end
      t0 = randi([Nobs + 1, T]); hist = t0 - Nobs:t0 - 1;
      xs = D.Z(i, [hist t0]); xs = xs + 0.001 * max(abs(xs), 1) .* randn(size(xs));   % 60 dB noise
      sc = max(abs(xs));
      Vh = (xs(1:Nobs)' / sc) .^ (5:-1:0);                 % scaled Vandermonde
      xh = 1.01 * xs(end);
      % NF-VDVM: fixed coefficients for this meter
      zf = -5 + 10 * rand(6, 1);
      Pf = @(x) polyval(zf, x);
      cf = Vh \ Pf(xs(1:Nobs))';                            % attacker regression
      forged = polyval(cf, xh / sc);
      succ(1) = succ(1) + (abs(forged - Pf(xh)) <= eta * abs(Pf(xh)));
      % RP-VDVM: fresh coefficients per slot
      Z6 = -5 + 10 * rand(6, Nobs + 1);
      dh = arrayfun(@(k) polyval(Z6(:, k), xs(k)), 1:Nobs);
      cr = Vh \ dh';
      forged = polyval(cr, xh / sc); truth = polyval(Z6(:, end), xh);
      succ(2) = succ(2) + (abs(forged - truth) <= eta * abs(truth));
      % PolyTag on the scalar measurement (m = 1), fresh (r, s) per slot
      q = pt_quantize(xs, delta); r = pt_randfield(1, Nobs + 1); s = pt_randfield(1, Nobs + 1);
      tau = pt_tag(q, r, s);
      ct = Vh \ double(tau(1:Nobs))';
      guess = polyval(ct, xh / sc);
      guess = uint64(mod(round(guess), 2^61 - 1));
      succ(3) = succ(3) + (pt_tag(pt_quantize(xh, delta), r(end), s(end)) == guess);
    end
    fprintf(fid, '%s,%d,%.4f,%.4f,%.4f\n', cases{c}, Nobs, succ / trials);
    fprintf('%s Nobs=%3d: NF %.3f  RP %.3f  PolyTag %.3f\n', cases{c}, Nobs, succ / trials);
  end
  clear D
end
fclose(fid);

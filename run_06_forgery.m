%RUN_06_FORGERY  Empirical check of Lemma 1 (forgery bound m/p) in reduced fields GF(p), p < 2^20.
%   Optimal adversary: plants m distinct roots, i.e. picks the difference
%   polynomial Q(r) = prod_k (r - a_k) and sets x_hat - x and tau_hat - tau from
%   its coefficients; it succeeds exactly when the secret r is a root, so its
%   success probability should equal the bound m/p.
%   Random adversary: random nonzero difference and random tag offset (~1/p).
%   Arithmetic in double is exact here because all products are < 2^40.
%   Reference platform (paper, Section IX): HP laptop, Intel Core i7-1255U (10 cores),
%   GNU Octave 8.4.0, MATPOWER 8.1.1-dev. The CPU actually used is
%   recorded in results/00_platform.txt by platform_info (called from run_all).
cfg = [131071 108; 131071 980; 131071 2244; 524287 108; 524287 980; 524287 2244];
trials = 200000; chunk = 5000;
fid = fopen('results/06_forgery.csv', 'w');
fprintf(fid, 'p,m,trials,opt_successes,opt_rate,bound_m_over_p,opt_95ci_lo,opt_95ci_hi,rand_successes,rand_rate,one_over_p\n');
for c = 1:size(cfg, 1)
  p = cfg(c, 1); m = cfg(c, 2); rng(600 + c);
  roots_ = randperm(p, m) - 1;                         % m distinct roots in GF(p)
  q = 1;                                               % coefficients, highest degree first
  for k = 1:m, q = mod(conv(q, [1, mod(-roots_(k), p)]), p); end
  dx_opt = q(1:m)';                                    % coeff of r^m ... r^1  -> x_1 ... x_m
  dtau_opt = mod(-q(m+1), p);
  succ = [0 0];
  for b = 1:trials/chunk
    r = randi([0 p-1], 1, chunk); s = randi([0 p-1], 1, chunk);
    X = randi([0 p-1], m, chunk);
    tau = small_tag(X, r, s, p);
    % optimal adversary
    Xh = mod(X + dx_opt, p);
    succ(1) = succ(1) + sum(small_tag(Xh, r, s, p) == mod(tau + dtau_opt, p));
    % random adversary (fresh random difference per trial; first entry forced nonzero)
    DX = randi([0 p-1], m, chunk); DX(1, :) = randi([1 p-1], 1, chunk);
    Xh = mod(X + DX, p);
    succ(2) = succ(2) + sum(small_tag(Xh, r, s, p) == mod(tau + randi([0 p-1], 1, chunk), p));
  end
  rate = succ(1) / trials; se = sqrt(rate * (1 - rate) / trials);
  fprintf(fid, '%d,%d,%d,%d,%.5g,%.5g,%.5g,%.5g,%d,%.3g,%.3g\n', p, m, trials, succ(1), rate, m/p, rate - 1.96*se, rate + 1.96*se, succ(2), succ(2)/trials, 1/p);
  fprintf('p=%d m=%d: optimal %d/%d = %.5f (bound %.5f, 95%% CI %.5f-%.5f); random %d (1/p*trials = %.1f)\n', ...
    p, m, succ(1), trials, rate, m/p, rate-1.96*se, rate+1.96*se, succ(2), trials/p);
end
fclose(fid);

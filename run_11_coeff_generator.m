%RUN_11_COEFF_GENERATOR  Statistics of the RP-VDVM coefficient generator as
%   implemented in fourth.m / coefficient_logic.m (HMAC-SHA256 PRF followed by
%   bytesToUniform: u = mod(sum_i b_i * i, 1e6) / 1e6, zeta = -5 + 10 u).
%   Because sum_i b_i * i <= 255 * 528 = 134640 < 1e6, u never exceeds 0.135,
%   so zeta is confined to about [-5, -3.65] instead of [-5, 5].
%   Reference platform (paper, Section IX): HP laptop, Intel Core i7-1255U (10 cores),
%   GNU Octave 8.4.0, MATPOWER 8.1.1-dev. The CPU actually used is
%   recorded in results/00_platform.txt by platform_info (called from run_all).
fid = fopen('results/11_coeff_generator.csv', 'w');
fprintf(fid, 'key,samples,zeta_min,zeta_max,zeta_mean,zeta_sd,ideal_uniform_sd\n');
keys = {'public_seed_2025', 'secret_key_1'};
for kk = 1:numel(keys)
  z = [];
  for meter = 1:108
    for t = 1:24
      for k = 1:6
        b = double(hmac_sha256(keys{kk}, sprintf('RPVDVM_%d_%d_%d', meter, t, k)));
        u = mod(sum(b(:) .* (1:32)'), 1e6) / 1e6;
        z(end+1) = -5 + 10 * u; %#ok
      end
    end
  end
  fprintf(fid, '%s,%d,%.4f,%.4f,%.4f,%.4f,%.4f\n', keys{kk}, numel(z), min(z), max(z), mean(z), std(z), 10/sqrt(12));
  fprintf('%s: n=%d  zeta in [%.3f, %.3f], mean %.3f, sd %.3f (uniform on [-5,5] would have sd %.3f)\n', ...
    keys{kk}, numel(z), min(z), max(z), mean(z), std(z), 10/sqrt(12));
end
fclose(fid);

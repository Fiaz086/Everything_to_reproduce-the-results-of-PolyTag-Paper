function d = rp_dummy(x, C)
%RP_DUMMY  RP-VDVM dummy values x' = sum_{k=1}^{6} zeta_k x^(6-k)  (Horner, double).
%   x: m x K measurements; C: 6 x m x K coefficients drawn from [-5, 5].
d = squeeze(C(1, :, :));
if isvector(d), d = reshape(d, size(x)); end
for k = 2:6
  ck = squeeze(C(k, :, :)); if isvector(ck), ck = reshape(ck, size(x)); end
  d = d .* x + ck;
end
end

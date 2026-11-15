function tau = corr_tags(F, X, s, m, N, d)
%CORR_TAGS  Keyed-syndrome tags tau_l = s_l + sum_i z_i r^(l*i), l = 1..2d (Eq. (9)).
%   F: field elements of the vectors (m*N x 4), X: corr_powtable(r, m), s: N x 4 x 2d masks.
%   Returns tau as N x 4 x 2d.
tau = zeros(N, 4, 2*d, 'uint64'); Xl = X;
for l = 1:2*d
  if l > 1, Xl = f127_mul(Xl, X); end
  tau(:, :, l) = f127_add(s(:, :, l), corr_wsum(F, Xl, m, N));
end
end

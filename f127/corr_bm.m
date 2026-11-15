function [C, L] = corr_bm(S, d)
%CORR_BM  Berlekamp-Massey over GF(2^127 - 1), run in lockstep for N syndrome sequences.
%   S: N x 4 x 2d syndromes S_1..S_2d. Returns the connection polynomials C (N x 4 x (2d+1),
%   C(:,:,1) = 1, C(x) = prod (1 - X_j x) when at most d errors) and their lengths L (N x 1).
N = size(S, 1); D = 2*d + 1;
one = zeros(N, 4, 'uint64'); one(:, 1) = 1;
C = zeros(N, 4, D, 'uint64'); C(:, :, 1) = one;
B = C; L = zeros(N, 1); mm = ones(N, 1); b = one;
for n = 0:2*d-1
  disc = S(:, :, n + 1);                          % S_{n+1} + sum_{i=1..n} C_i S_{n+1-i}
  for i = 1:n
    disc = f127_add(disc, f127_mul(C(:, :, i + 1), S(:, :, n + 1 - i)));
  end
  nz = any(disc ~= 0, 2);
  if any(nz)
    coef = zeros(N, 4, 'uint64');
    coef(nz, :) = f127_mul(disc(nz, :), f127_inv(b(nz, :)));
    T = C;
    for sh = unique(mm(nz))'                     % C <- C - coef * x^mm * B
      g = nz & mm == sh;
      for k = 1:D - sh
        C(g, :, k + sh) = f127_sub(C(g, :, k + sh), f127_mul(coef(g, :), B(g, :, k)));
      end
    end
    upd = nz & (2 * L <= n);
    L(upd) = n + 1 - L(upd); B(upd, :, :) = T(upd, :, :); b(upd, :) = disc(upd, :);
    mm(upd) = 1; mm(~upd) = mm(~upd) + 1;
  else
    mm = mm + 1;
  end
end
end

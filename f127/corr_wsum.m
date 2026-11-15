function S = corr_wsum(F, Xl, m, N)
%CORR_WSUM  S(n) = sum_i F(i,n) * Xl(i,n) mod p for the m x N layout of corr_powtable.
P = f127_mul(F, Xl);
L = reshape(sum(reshape(P, m, N, 4), 1, 'native'), N, 4);   % limb sums < m * 2^32
S = f127_fold(L);
end

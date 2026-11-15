function tau = pt_tag(X, r, s)
%PT_TAG  PolyTag over each column of X (m x K, uint64 field elements).
%   tau(k) = s(k) + sum_i X(i,k) * r(k)^(m-i+1)  (mod 2^61-1), via Horner.
[m, K] = size(X);
h = zeros(1, K, 'uint64');
r = reshape(r, 1, K); s = reshape(s, 1, K);
for i = 1:m
  h = pt_mulmod(pt_addmod(h, X(i, :)), r);
end
tau = pt_addmod(h, s);
end

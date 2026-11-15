function tau = pt_tag_subsets(x, M, r, s)
%PT_TAG_SUBSETS  T PolyTags over subsets of each vector.
%   x: m x K field elements; M: T x m binary design; r, s: T x K keys.
%   tau(l,k) = s(l,k) + sum_{i: M(l,i)=1} x(i,k) r(l,k)^(m-i+1)  (positions are
%   kept fixed, so each tag is a PolyTag over a zero-padded vector).
[T, m] = size(M); K = size(x, 2);
h = zeros(T, K, 'uint64');
Mu = uint64(M);
for i = 1:m
  h = pt_mulmod(pt_addmod(h, Mu(:, i) .* x(i, :)), r);
end
tau = pt_addmod(h, s);
end

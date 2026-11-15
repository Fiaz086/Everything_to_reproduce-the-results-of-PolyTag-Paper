function tau = small_tag(X, r, s, p)
%SMALL_TAG  PolyTag in a small prime field GF(p), p < 2^20 (exact in double).
h = zeros(1, size(X, 2));
for i = 1:size(X, 1)
  h = mod((h + X(i, :)) .* r, p);
end
tau = mod(h + s, p);
end

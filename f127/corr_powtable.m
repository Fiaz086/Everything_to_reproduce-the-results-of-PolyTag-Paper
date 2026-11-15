function X = corr_powtable(r, m)
%CORR_POWTABLE  X(i + (n-1)*m, :) = r(n)^i for i = 1..m and each row n of r (N x 4 limbs).
%   Built by repeated doubling: about two full-size field multiplications in total.
N = size(r, 1);
X = zeros(m * N, 4, 'uint64');
base = (0:N-1) * m;                              % offset of vector n
X(base + 1, :) = r;
b = 1;
while b < m
  len = min(b, m - b);
  src = reshape((1:len)' + base, [], 1);         % rows 1..len of every vector
  dst = src + b;                                 % rows b+1..b+len
  mul = reshape(repmat(base + b, len, 1), [], 1);% r^b of every vector, repeated len times
  X(dst, :) = f127_mul(X(src, :), X(mul, :));
  b = b + len;
end
end

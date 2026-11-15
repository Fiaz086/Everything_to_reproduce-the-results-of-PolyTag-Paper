function R = f127_mul(A, B)
%F127_MUL  Elementwise product modulo p = 2^127 - 1 of K x 4 limb arrays (32-bit limbs in uint64).
M32 = uint64(4294967295);
K = size(A, 1);
C = zeros(K, 8, 'uint64');
for i = 1:4
  for j = 1:4
    P = A(:, i) .* B(:, j);                      % < 2^64, exact
    C(:, i+j-1) = C(:, i+j-1) + bitand(P, M32);
    C(:, i+j)   = C(:, i+j)   + bitshift(P, -32);
  end
end
R = f127_fold(C);
end

function R = f127_inv(A)
%F127_INV  Elementwise inverse modulo p = 2^127 - 1 by Fermat, A^(p-2). A must be nonzero.
% p - 2 = 2^127 - 3: binary 1...1101 (127 bits): all ones except bit 1.
R = A; base = A;                                 % bit 0 is 1
for k = 1:126
  base = f127_mul(base, base);                   % A^(2^k)
  if k ~= 1, R = f127_mul(R, base); end
end
end

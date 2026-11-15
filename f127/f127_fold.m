function R = f127_fold(L)
%F127_FOLD  Reduce integers given as 32-bit limbs (K x n uint64, least significant limb first,
%   each limb < 2^63) modulo p = 2^127 - 1. Returns K x 4 limbs, canonical (0 <= value < p).
M32 = uint64(4294967295);
K = size(L, 1);
while true
  % carry propagation to 32-bit limbs (append limbs while the top one overflows)
  n = size(L, 2);
  for k = 1:n-1
    L(:, k+1) = L(:, k+1) + bitshift(L(:, k), -32);
    L(:, k) = bitand(L(:, k), M32);
  end
  while any(L(:, end) > M32)
    L(:, end+1) = bitshift(L(:, end), -32); %#ok<AGROW>
    L(:, end-1) = bitand(L(:, end-1), M32);
  end
  n = size(L, 2);
  if n < 4, L(:, end+1:4) = 0; n = 4; end
  if n == 4 && all(L(:, 4) <= uint64(2147483647)), break; end
  % fold: value = lo + hi, lo = bits 0..126, hi = value >> 127   (2^127 = 1 mod p)
  Lp = [L, zeros(K, 1, 'uint64')];
  nh = n - 3;
  hi = zeros(K, max(nh, 1), 'uint64');
  for j = 1:nh
    hi(:, j) = bitor(bitshift(Lp(:, j+3), -31), bitand(bitshift(Lp(:, j+4), 1), M32));
  end
  lo = L(:, 1:4); lo(:, 4) = bitand(lo(:, 4), uint64(2147483647));
  L = zeros(K, max(4, nh), 'uint64');
  L(:, 1:4) = lo; L(:, 1:nh) = L(:, 1:nh) + hi;
end
R = L(:, 1:4);
isP = R(:, 1) == M32 & R(:, 2) == M32 & R(:, 3) == M32 & R(:, 4) == uint64(2147483647);
R(isP, :) = 0;                                   % p == 0
end

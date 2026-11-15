function P = pt_P()
%PT_P  Mersenne prime p = 2^61 - 1 as uint64 (exact; do not build it from a double).
P = bitshift(uint64(1), 61) - uint64(1);
end

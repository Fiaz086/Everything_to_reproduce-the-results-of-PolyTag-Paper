function t = pt_reduce(t)
%PT_REDUCE  Reduce uint64 values (< 2^64) modulo p = 2^61-1 using 2^61 == 1 (mod p).
P = pt_P();
t = bitand(t, P) + bitshift(t, -61);
t = bitand(t, P) + bitshift(t, -61);
ge = t >= P;
t(ge) = t(ge) - P;
end

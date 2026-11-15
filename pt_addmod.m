function c = pt_addmod(a, b)
%PT_ADDMOD  (a + b) mod (2^61-1) for uint64 arrays a, b < p.
c = pt_reduce(a + b);
end

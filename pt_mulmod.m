function c = pt_mulmod(a, b)
%PT_MULMOD  Exact (a*b) mod (2^61-1) for uint64 arrays a, b < 2^61.
%   Splits operands into 31-bit and 30-bit limbs so that every partial
%   product fits in 64 bits. All arithmetic stays in uint64 (never mixes
%   with doubles, which would round above 2^53).
M31 = uint64(2147483647);            % 2^31 - 1
M30 = uint64(1073741823);            % 2^30 - 1
al = bitand(a, M31);  ah = bitshift(a, -31);
bl = bitand(b, M31);  bh = bitshift(b, -31);
hh  = ah .* bh;                      % < 2^60, weight 2^62 == 2 (mod p)
mid = ah .* bl + al .* bh;           % < 2^62, weight 2^31
ll  = al .* bl;                      % < 2^62, weight 1
mh = bitshift(mid, -30);             % mid*2^31 = mh*2^61 + ml*2^31 == mh + ml*2^31
ml = bitand(mid, M30);
t = uint64(2) .* hh + mh + bitshift(ml, 31) + ll;   % < 2^63
c = pt_reduce(t);
end

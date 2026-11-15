function q = pt_quantize(z, delta)
%PT_QUANTIZE  Fixed-point encoding of real measurements into GF(2^61-1).
%   q = round(z/delta), negative values mapped to p - |q|.
P = pt_P();
qi = round(z / delta);                    % |qi| << 2^53, exact in double
u = uint64(abs(qi));
neg = qi < 0;
u(neg) = P - u(neg);
q = u;
end

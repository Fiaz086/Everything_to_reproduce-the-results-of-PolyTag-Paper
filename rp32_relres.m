function rr = rp32_relres(d32, x, Cf)
%RP32_RELRES  Largest relative dummy residual per vector at the control centre,
%   for float32 transport of measurements x (m x K) and received dummies d32.
P = rp_dummy(double(single(x)), Cf);
rr = max(abs(d32 - P) ./ max(abs(P), realmin), [], 1);
end

function r = pt_randfield(varargin)
%PT_RANDFIELD  Uniform elements of GF(2^61-1) (simulation stand-in for the PRF).
%   In simulation the PRF is modelled as a random function (as in Theorem 1);
%   the C implementation derives (r, s) with AES-128 instead.
hi = uint64(randi([0, 2^29-1], varargin{:}));
lo = uint64(randi([0, 2^32-1], varargin{:}));
r = pt_reduce(bitshift(hi, 32) + lo);
end

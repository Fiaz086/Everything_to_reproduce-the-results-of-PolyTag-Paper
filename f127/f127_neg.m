function R = f127_neg(A)
%F127_NEG  Additive inverse modulo p = 2^127 - 1 (K x 4 limbs): p - A, and 0 for A = 0.
M32 = uint64(4294967295);
P = [M32 M32 M32 uint64(2147483647)];
R = repmat(P, size(A, 1), 1) - A;                % limbwise, no borrow needed since A <= p
R(all(A == 0, 2), :) = 0;
end

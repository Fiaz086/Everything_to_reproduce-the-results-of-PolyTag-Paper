function R = f127_add(A, B)
%F127_ADD  Elementwise sum modulo p = 2^127 - 1 (K x 4 limbs).
R = f127_fold(A + B);
end

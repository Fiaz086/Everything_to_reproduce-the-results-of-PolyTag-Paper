function R = f127_sub(A, B)
%F127_SUB  Elementwise difference A - B modulo p = 2^127 - 1 (K x 4 limbs).
R = f127_fold(A + f127_neg(B));
end

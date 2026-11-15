function R = f127_from_int(v)
%F127_FROM_INT  Field elements from integers |v| < 2^53 (doubles); negatives map to p - |v|.
v = v(:); a = uint64(abs(v));
R = zeros(numel(v), 4, 'uint64');
R(:, 1) = bitand(a, uint64(4294967295)); R(:, 2) = bitshift(a, -32);
neg = v < 0; R(neg, :) = f127_neg(R(neg, :));
end

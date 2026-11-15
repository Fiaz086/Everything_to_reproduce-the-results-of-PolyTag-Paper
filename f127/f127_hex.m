function h = f127_hex(a)
%F127_HEX  Hexadecimal string (32 digits) of one field element (1 x 4 limbs).
h = sprintf('%08x%08x%08x%08x', a(4), a(3), a(2), a(1));
end

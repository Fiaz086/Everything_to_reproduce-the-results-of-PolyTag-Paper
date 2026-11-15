function s = f127_to_str(A)
%F127_TO_STR  Hexadecimal strings (32 digits) of K x 4 limb arrays, for test files.
s = cell(size(A, 1), 1);
for k = 1:size(A, 1)
  s{k} = sprintf('%08x%08x%08x%08x', A(k, 4), A(k, 3), A(k, 2), A(k, 1));
end
end

function R = f127_rand(K, nonzero)
%F127_RAND  K uniform elements of GF(2^127 - 1) (simulation stand-in for the PRF, as in Theorem 1).
%   With nonzero = true, zero is excluded (for the evaluation point r).
if nargin < 2, nonzero = false; end
R = zeros(K, 4, 'uint64');
R(:, 1:3) = uint64(randi([0, 4294967295], K, 3));
R(:, 4) = uint64(randi([0, 2147483647], K, 1));
bad = (R(:,1) == 4294967295 & R(:,2) == 4294967295 & R(:,3) == 4294967295 & R(:,4) == 2147483647);
if nonzero, bad = bad | all(R == 0, 2); end
if any(bad), R(bad, :) = f127_rand(nnz(bad), nonzero); end
end

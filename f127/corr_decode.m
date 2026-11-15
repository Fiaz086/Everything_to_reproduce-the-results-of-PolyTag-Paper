function [status, pos, val] = corr_decode(S, X, Y, m, N, d)
%CORR_DECODE  Keyed-syndrome decoding with fail-safe acceptance (Section VII-B).
%   S: syndromes (N x 4 x 2d); X, Y: tables of r^i and r^-i (corr_powtable).
%   status: 1 = all syndromes zero, accepted unchanged; 2 = corrected and accepted;
%           0 = rejected. For status 2, pos{n} are the corrected positions and val{n} the
%   changes Delta (field elements) to subtract from the received values.
status = zeros(N, 1); pos = cell(N, 1); val = cell(N, 1);
allzero = all(all(S == 0, 2), 3);
status(allzero) = 1;
[C, L] = corr_bm(S, d);
cand = find(~allzero & L >= 1 & L <= d);         % L > d: beyond capacity, rejected
if isempty(cand), return; end
% root search: C(X_i^{-1}) = 0, Horner on the m x |cand| block of the r^-i table
nc = numel(cand); Dm = max(L(cand));
rows = reshape((1:m)' + (cand' - 1) * m, [], 1);
Yc = Y(rows, :);
v = zeros(m * nc, 4, 'uint64');
for k = Dm:-1:0
  ck = C(cand, :, k + 1); ck = ck(reshape(repmat(1:nc, m, 1), [], 1), :);
  if k == Dm, v = ck; else, v = f127_add(f127_mul(v, Yc), ck); end
end
isroot = reshape(all(v == 0, 2), m, nc);
for g = unique(L(cand))'                         % solve the Vandermonde systems, grouped by L
  sel = find(L(cand) == g & sum(isroot, 1)' == g);   % number of roots must equal L
  if isempty(sel), continue; end
  ng = numel(sel); J = zeros(ng, g);
  for t = 1:ng, J(t, :) = find(isroot(:, sel(t)))'; end
  inst = cand(sel);
  Xj = cell(1, g); for j = 1:g, Xj{j} = X(J(:, j) + (inst - 1) * m, :); end
  % A(l,j) = X_j^l, l = 1..2d; rhs = S_l
  A = cell(2*d, g);
  for j = 1:g
    A{1, j} = Xj{j};
    for l = 2:2*d, A{l, j} = f127_mul(A{l-1, j}, Xj{j}); end
  end
  M = A(1:g, :); rhs = cell(g, 1); for l = 1:g, rhs{l} = S(inst, :, l); end
  for k = 1:g                                    % Gaussian elimination, no pivoting needed
    iv = f127_inv(M{k, k});
    for j = k:g, M{k, j} = f127_mul(M{k, j}, iv); end
    rhs{k} = f127_mul(rhs{k}, iv);
    for l = [1:k-1, k+1:g]
      f = M{l, k};
      for j = k:g, M{l, j} = f127_sub(M{l, j}, f127_mul(f, M{k, j})); end
      rhs{l} = f127_sub(rhs{l}, f127_mul(f, rhs{k}));
    end
  end
  ok = true(ng, 1);                              % fail-safe: all 2d syndromes reproduced
  for l = 1:2*d
    acc = zeros(ng, 4, 'uint64');
    for j = 1:g, acc = f127_add(acc, f127_mul(rhs{j}, A{l, j})); end
    ok = ok & all(acc == S(inst, :, l), 2);
  end
  for t = find(ok)'
    status(inst(t)) = 2; pos{inst(t)} = J(t, :);
    val{inst(t)} = cell2mat(cellfun(@(x) x(t, :), rhs, 'UniformOutput', false));
  end
end
end

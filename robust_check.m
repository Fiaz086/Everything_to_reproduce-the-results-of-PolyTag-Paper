function [ok, C, c] = robust_check(Gdev, y, k, nx)
%ROBUST_CHECK  Is rank(H_{Y\C}) = nx for every compromise set C (|C|<=k) of
%   authenticated devices? G = sum_j H_j'H_j; a state direction is unobservable
%   when G has an eigenvalue below tol*max eigenvalue (tol = 1e-10).
%   On failure returns the compromise set C and null-space attack directions c
%   (one per column), made sparse by reduced row echelon form so that each
%   column is (close to) one unobservable island.
tol = 1e-10;
Y = find(y(:)' > 0.5); ok = true; C = []; c = [];
G = zeros(nx); for j = Y, G = G + Gdev{j}; end
for kk = 0:k
  if kk == 0, sets = zeros(1, 0); elseif numel(Y) >= kk, sets = nchoosek(Y, kk); else, sets = []; end
  for s = 1:size(sets, 1)
    Gs = G; for j = sets(s, :), Gs = Gs - Gdev{j}; end
    Gs = (Gs + Gs') / 2;
    [Vv, ev] = eig(Gs); ev = diag(ev);
    small = ev < tol * max(ev);
    if ~any(small), continue; end
    Rr = rref(Vv(:, small)');
    c = Rr(any(abs(Rr) > 1e-9, 2), :)';
    ok = false; C = sets(s, :); return;
  end
end
end

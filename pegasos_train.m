function [w, b] = pegasos_train(X, y, lambda, epochs, seed)
%PEGASOS_TRAIN  Linear SVM (hinge loss, L2) by the Pegasos stochastic sub-gradient
%   method (Shalev-Shwartz et al., 2011). X: d x N (standardized), y in {-1,+1}.
rng(seed); [d, N] = size(X); w = zeros(d, 1); b = 0; t = 0;
for ep = 1:epochs
  for i = randperm(N)
    t = t + 1; eta = 1 / (lambda * t);
    if y(i) * (w' * X(:, i) + b) < 1
      w = (1 - eta * lambda) * w + eta * y(i) * X(:, i); b = b + eta * y(i);
    else
      w = (1 - eta * lambda) * w;
    end
  end
end
end

%RUN_09_SVM  Data-driven baseline: linear SVM (Pegasos) trained to separate honest
%   from stealth-attacked measurement vectors, on the same data as run_02.
%   Half the snapshots are attacked (a = H c, c ~ N(0, sigma_c^2 I)); 70/30 split.
%   Reference platform (paper, Section IX): HP laptop, Intel Core i7-1255U (10 cores),
%   GNU Octave 8.4.0, MATPOWER 8.1.1-dev. The CPU actually used is
%   recorded in results/00_platform.txt by platform_info (called from run_all).
setup_paths;
cases = {'case14','case30','case118','case300'};
sigc = [1e-4 1e-3 1e-2]; SNR = 30; lambda = 1e-4; epochs = 10;
fid = fopen('results/09_svm.csv', 'w');
fprintf(fid, 'system,sigma_c,test_TPR,test_FPR,test_accuracy,train_time_s,infer_us_per_sample\n');
for c = 1:numel(cases)
  load(fullfile(pwd, 'data', [cases{c} '.mat'])); m = D.m; nx = 2*D.n - 1; T = size(D.Z, 2);
  for sc = sigc
    rng(900 + 10*c + round(-log10(sc)));
    Zm = D.Z + 10^(-SNR/20) * max(abs(D.Z), 1) .* randn(m, T);
    y = -ones(1, T); att = randperm(T, T/2); y(att) = 1;
    for k = att
      [~, H] = meas_model(D.Ybus, D.Yf, D.Yt, D.branch, D.V(:, k), D.ref, D.baseMVA);
      Zm(:, k) = Zm(:, k) + H * (sc * randn(nx, 1));
    end
    perm = randperm(T); tr = perm(1:round(0.7*T)); te = perm(round(0.7*T)+1:end);
    mu = mean(Zm(:, tr), 2); sd = std(Zm(:, tr), 0, 2); sd(sd == 0) = 1;
    Xtr = (Zm(:, tr) - mu) ./ sd; Xte = (Zm(:, te) - mu) ./ sd;
    tic; [w, b] = pegasos_train(Xtr, y(tr), lambda, epochs, 1); ttr = toc;
    tic; for rep = 1:10, yh = sign(w' * Xte + b); end; tinf = toc / 10 / numel(te) * 1e6;
    tpr = mean(yh(y(te) == 1) == 1); fpr = mean(yh(y(te) == -1) == 1); acc = mean(yh == y(te));
    fprintf(fid, '%s,%g,%.4f,%.4f,%.4f,%.2f,%.3f\n', cases{c}, sc, tpr, fpr, acc, ttr, tinf);
    fprintf('%s sc=%g: TPR %.3f FPR %.3f acc %.3f train %.1f s infer %.2f us\n', cases{c}, sc, tpr, fpr, acc, ttr, tinf);
  end
  clear D
end
fclose(fid);

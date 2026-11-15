function make_figures(resdir, outdir)
%MAKE_FIGURES  Draw the data figures of the paper from the result files in results/.
%   make_figures                 reads results/ and writes figures/ (PDF and PNG)
%   make_figures(resdir, outdir) uses other folders
%
%   Paper figure  File                          Data
%   Fig. 2        Fig2_detection_sensitivity    05_single_point.csv, 12_delta_sweep.csv
%   Fig. 3        Fig4_forgery_probability      06_forgery.csv
%   Fig. 4        Fig5_localization_overhead    07_localization.csv
%   Fig. 5        Fig6_computational_cost       12_bench.csv
%   Fig. 6        Fig8_correction_overhead      07_localization.csv and the byte counts of Section X-J
%   (Fig. 1, the architecture diagram, is a TikZ drawing with no data.)
%   For each figure, the plotted values are also printed, so they can be checked against the
%   CSV files and the tables and text of the paper.
if nargin < 1, resdir = 'results'; end
if nargin < 2, outdir = 'figures'; end
% Use full paths: exist('figures','dir') would also find folders of that name on the MATLAB
% path (e.g. in toolboxes) and skip creating the folder here.
if ~is_absolute(resdir), resdir = fullfile(pwd, resdir); end
if ~is_absolute(outdir), outdir = fullfile(pwd, outdir); end
if exist(outdir, 'dir') ~= 7, mkdir(outdir); end
fig_detection(resdir, outdir);
fig_forgery(resdir, outdir);
fig_localization(resdir, outdir);
fig_timing(resdir, outdir);
fig_correction_bytes(resdir, outdir);
fprintf('\nAll figures written to %s\n', outdir);
end

% ======================================================================================
function fig_detection(resdir, outdir)
% Fig. 2: single-measurement attacks. (a) RP-VDVM detection, (b) share of attacks that alter
% PolyTag's transmitted value at delta = 0.01 MW, (c) effect of delta on the 300-bus system.
T5 = read_csv(fullfile(resdir, '05_single_point.csv'));
T12 = read_csv(fullfile(resdir, '12_delta_sweep.csv'));
sys = {'case14', 'case30', 'case118', 'case300'};
lab = {'IEEE 14-bus', 'IEEE 30-bus', 'IEEE 118-bus', 'IEEE 300-bus'};
col = {[0.67 0.67 0.67], [0.53 0.53 0.53], [0.33 0.33 0.33], [0 0 0]};
mk = {'o', 's', '^', 'd'};
fh = new_figure(6.77, 2.74);
fprintf('\n== Fig. 2 (Fig2_detection_sensitivity): attacks detected / altering the value (%%)\n');
for panel = 1:2
  subplot(1, 3, panel); hold on;
  for k = 1:4
    i = strcmp(T5.system, sys{k}); x = T5.rel_change(i);
    if panel == 1, y = 100 * T5.RP32naive_det(i); else, y = 100 * T5.PT_changed_frac(i); end
    fc = 'w'; if k == 4, fc = col{k}; end
    plot(x, y, '-', 'Color', col{k}, 'Marker', mk{k}, 'MarkerFaceColor', fc, 'LineWidth', 1.1, 'MarkerSize', 5);
    fprintf('  (%s) %-12s %s\n', char('a' + panel - 1), lab{k}, sprintf('%6.2f ', y));
  end
  if panel == 1
    plot([6e-7 1.6e-2], [1 1], ':', 'Color', [0.75 0.27 0.12], 'LineWidth', 1);
    legend(lab, 'Location', 'east'); legend('boxoff');
    title('(a) RP-VDVM, 32-bit, \eta at 1% FP'); ylabel('Attacks detected / altering the value (%)');
  else
    title('(b) PolyTag, \delta = 0.01 MW');
  end
  style_axes(gca, 'log', 'linear'); xlim([6e-7 1.6e-2]); ylim([-3 104]); xlabel('Relative change \epsilon');
end
subplot(1, 3, 3); hold on;
i = strcmp(T12.system, 'case300') & T12.delta == 0.01;
plot(T12.rel_change(i), 100 * T12.RP32naive_det(i), ':x', 'Color', [0.75 0.27 0.12], 'LineWidth', 1.1, 'MarkerSize', 6);
fprintf('  (c) RP-VDVM        %s\n', sprintf('%6.2f ', 100 * T12.RP32naive_det(i)));
ls = {'-', '--', '-.'}; dl = [0.001 0.01 0.1]; mk3 = {'o', 's', '^'};
for k = 1:3
  i = strcmp(T12.system, 'case300') & T12.delta == dl(k);
  plot(T12.rel_change(i), 100 * T12.PT_changed_frac(i), ls{k}, 'Color', [0.12 0.31 0.60], 'Marker', mk3{k}, ...
       'MarkerFaceColor', 'w', 'LineWidth', 1.1, 'MarkerSize', 5);
  fprintf('  (c) delta = %-5g  %s\n', dl(k), sprintf('%6.2f ', 100 * T12.PT_changed_frac(i)));
end
legend({'RP-VDVM (detected)', 'PolyTag, \delta = 0.001 MW', 'PolyTag, \delta = 0.01 MW', 'PolyTag, \delta = 0.1 MW'}, ...
       'Location', 'northwest'); legend('boxoff');
style_axes(gca, 'log', 'linear'); xlim([6e-7 1.6e-2]); ylim([-3 104]);
title('(c) IEEE 300-bus, effect of \delta'); xlabel('Relative change \epsilon');
fprintf('  (columns: epsilon = 1e-6, 1e-5, 1e-4, 1e-3, 1e-2)\n');
save_figure(fh, outdir, 'Fig2_detection_sensitivity', 6.77, 2.74);
end

% ======================================================================================
function fig_forgery(resdir, outdir)
% Fig. 3: forgery success in reduced fields against the bound m/p (Lemma 1).
T = read_csv(fullfile(resdir, '06_forgery.csv'));
fh = new_figure(3.44, 3.2); hold on;
ps = [131071 524287]; pc = {[0.12 0.31 0.60], [0.75 0.27 0.12]}; pm = {'o', 's'}; off = [1.08 0.93];
fprintf('\n== Fig. 3 (Fig4_forgery_probability): optimal-adversary rate, 95%% CI, bound m/p, random successes\n');
for k = 1:2
  i = T.p == ps(k); m = T.m(i); mm = logspace(log10(60), log10(3000), 50);
  plot(mm, mm / ps(k), '-', 'Color', pc{k}, 'LineWidth', 1.1);
  y = T.opt_rate(i); lo = T.opt_95ci_lo(i); hi = T.opt_95ci_hi(i);
  he = errorbar(m, y, y - lo, hi - y, pm{k});
  set(he, 'Color', pc{k}, 'MarkerFaceColor', 'w', 'LineWidth', 0.9);
  plot([60 3000], [1 1] / ps(k), ':', 'Color', pc{k}, 'LineWidth', 1);
  rs = T.rand_successes(i); rr = T.rand_rate(i);
  for j = 1:numel(m)
    if rs(j) > 0, plot(m(j) * off(k), rr(j), 'x', 'Color', pc{k}, 'MarkerSize', 7, 'LineWidth', 1.2);
    else, plot(m(j) * off(k), 3 / 200000, 'v', 'Color', pc{k}, 'MarkerFaceColor', 'w', 'MarkerSize', 6); end
    fprintf('  p = %6d  m = %4d  rate %.4e  CI [%.4e, %.4e]  bound %.4e  random successes %d\n', ...
            ps(k), m(j), y(j), lo(j), hi(j), m(j) / ps(k), rs(j));
  end
end
style_axes(gca, 'log', 'log'); xlim([70 3000]); ylim([6e-7 6e-2]);
set(gca, 'XTick', [108 980 2244], 'XTickLabel', {'108', '980', '2,244'});
xlabel('Vector length m (measurements)'); ylabel('Forgery success probability');
title({'Lines: bound m/p; markers: optimal adversary (95% CI);', 'x / \nabla: random adversary; dotted: 1/p'}, 'FontWeight', 'normal');
save_figure(fh, outdir, 'Fig4_forgery_probability', 3.44, 3.2);
end

% ======================================================================================
function fig_localization(resdir, outdir)
% Fig. 4: exact-localization rate versus tag overhead (group testing, Section VII-A).
T = read_csv(fullfile(resdir, '07_localization.csv'));
sys = {'case118', 'case300'}; ttl = {'(a) IEEE 118-bus (m = 980)', '(b) IEEE 300-bus (m = 2,244)'};
fh = new_figure(6.0, 2.44);
ls = {'-', '--', '-.'}; mk = {'o', 's', '^'}; col = {[0 0 0], [0.33 0.33 0.33], [0.67 0.67 0.67]};
fprintf('\n== Fig. 4 (Fig5_localization_overhead): overhead (bytes) -> exact localization (%%)\n');
for s = 1:2
  subplot(1, 2, s); hold on;
  i0 = strcmp(T.system, sys{s}); m = T.m(find(i0, 1));
  for d = 1:3
    i = i0 & strcmp(T.design, 'random') & T.d == d;
    [x, o] = sort(T.overhead_bytes(i)); y = 100 * T.exact_recovery(i); y = y(o);
    plot(x, y, ls{d}, 'Color', col{d}, 'Marker', mk{d}, 'MarkerFaceColor', 'w', 'LineWidth', 1.1, 'MarkerSize', 5);
    fprintf('  %s random d = %d: %s\n', sys{s}, d, sprintf('%g B -> %.1f%%;  ', [x(:)'; y(:)']));
  end
  i = i0 & strcmp(T.design, 'binary');
  plot(T.overhead_bytes(i), 100 * T.exact_recovery(i), 'p', 'Color', [0.12 0.31 0.60], ...
       'MarkerFaceColor', [0.12 0.31 0.60], 'MarkerSize', 11);
  fprintf('  %s binary code d = 1: %g B -> %.1f%%;  RP-VDVM dummies: %d B\n', sys{s}, ...
          T.overhead_bytes(i), 100 * T.exact_recovery(i), 8 * m);
  plot([8 8] * m, [-3 104], ':', 'Color', [0.75 0.27 0.12], 'LineWidth', 1);
  style_axes(gca, 'log', 'linear'); xlim([60 25000]); ylim([-3 104]);
  set(gca, 'XTick', [100 1000 10000], 'XTickLabel', {'100', '1,000', '10,000'});
  title(ttl{s}); xlabel('Tag overhead per vector (bytes, log scale)');
  if s == 1
    ylabel('Exact localization (%)');
    legend({'Random design, d = 1', 'Random design, d = 2', 'Random design, d = 3', 'Binary-code design, d = 1'}, ...
           'Location', 'west'); legend('boxoff');
  end
end
save_figure(fh, outdir, 'Fig5_localization_overhead', 6.0, 2.44);
end

% ======================================================================================
function fig_timing(resdir, outdir)
% Fig. 5: median time to authenticate one measurement vector on the laptop (C benchmark).
T = read_csv(fullfile(resdir, '12_bench.csv'));
sch = {'RP-VDVM', 'AES128-CMAC', 'HMAC-SHA256', 'PolyTag', 'Poly1305', 'AES128-GMAC'};
lab = {'RP-VDVM', 'AES-128-CMAC', 'HMAC-SHA256', 'PolyTag', 'Poly1305', 'AES-128-GMAC'};
col = {[0.75 0.27 0.12], [0.33 0.33 0.33], [0.33 0.33 0.33], [0.12 0.31 0.60], [0.6 0.6 0.6], [0.6 0.6 0.6]};
ls = {'-', '--', '-', '-', '-', '--'}; mk = {'s', 'v', '^', 'o', 'd', '+'};
fh = new_figure(3.17, 2.6); hold on;
fprintf('\n== Fig. 5 (Fig6_computational_cost): median time per vector (us) for m = 108, 224, 980, 2244\n');
for k = 1:numel(sch)
  i = strcmp(T.scheme, sch{k}); [m, o] = sort(T.m(i)); t = T.median_ns_per_vector(i) / 1000; t = t(o);
  fc = 'w'; if strcmp(sch{k}, 'PolyTag'), fc = col{k}; end
  plot(m, t, ls{k}, 'Color', col{k}, 'Marker', mk{k}, 'MarkerFaceColor', fc, 'LineWidth', 1.1, 'MarkerSize', 5);
  fprintf('  %-13s %s\n', lab{k}, sprintf('%9.2f ', t));
end
style_axes(gca, 'log', 'log'); xlim([85 2900]);
set(gca, 'XTick', [108 224 980 2244], 'XTickLabel', {'108', '224', '980', '2,244'});
xlabel('Measurements per vector m (IEEE 14-, 30-, 118-, 300-bus)'); ylabel('Median time per vector (\mus)');
legend(lab, 'Location', 'northwest'); legend('boxoff');
save_figure(fh, outdir, 'Fig6_computational_cost', 3.17, 2.6);
end

% ======================================================================================
function fig_correction_bytes(resdir, outdir)
% Fig. 6: bytes per 300-bus vector needed to handle d tampered measurements.
%   Group testing: smallest tested design (07_localization.csv) with >= 99% exact localization.
%   Keyed syndromes: 2d tags of 16 bytes (p = 2^127 - 1). CCMAC-EC, theoretical best: d^2 tags of
%   128 bits plus d extra 8-byte items. RP-VDVM: one 8-byte dummy per measurement.
T = read_csv(fullfile(resdir, '07_localization.csv'));
i0 = strcmp(T.system, 'case300'); m = T.m(find(i0, 1));
d = 1:5; syn = 32 * d; ccm = 16 * d.^2 + 8 * d; gt = nan(1, 3);
for k = 1:3
  i = i0 & T.d == k & T.exact_recovery >= 0.99;
  if any(i), gt(k) = min(T.overhead_bytes(i)); end
end
fh = new_figure(3.17, 2.4); hold on;
plot(1:3, gt, '-s', 'Color', [0.33 0.33 0.33], 'MarkerFaceColor', 'w', 'LineWidth', 1.1);
plot(d, ccm, '--^', 'Color', [0.6 0.6 0.6], 'MarkerFaceColor', [0.85 0.85 0.85], 'LineWidth', 1.1);
plot(d, syn, '-o', 'Color', [0.12 0.31 0.60], 'MarkerFaceColor', [0.12 0.31 0.60], 'LineWidth', 1.6);
plot([0.8 5.2], [8 8] * m, ':', 'Color', [0.75 0.27 0.12], 'LineWidth', 1.2);
style_axes(gca, 'linear', 'log'); xlim([0.8 5.2]); ylim([15 3e4]); set(gca, 'XTick', 1:5);
xlabel('Tampered measurements to handle, d'); ylabel('Bytes per vector (IEEE 300-bus)');
legend({'Group testing, locate only (measured, >=99% exact)', 'CCMAC-EC, theoretical best (locate + correct)', ...
        'Keyed syndromes, p = 2^{127} - 1 (locate + correct)', sprintf('RP-VDVM dummies (%d B)', 8 * m)}, ...
       'Location', 'northwest', 'FontSize', 6); legend('boxoff');
fprintf('\n== Fig. 6 (Fig8_correction_overhead): bytes per vector, d = 1..5\n');
fprintf('  group testing (>=99%% exact): %s\n', sprintf('%g ', gt));
fprintf('  CCMAC-EC theoretical best:    %s\n', sprintf('%g ', ccm));
fprintf('  keyed syndromes:              %s\n', sprintf('%g ', syn));
fprintf('  ratios: CCMAC/syndromes %s; group testing/syndromes %s\n', ...
        sprintf('%.2f ', ccm ./ syn), sprintf('%.2f ', gt ./ syn(1:3)));
fprintf('  RP-VDVM dummies: %d B\n', 8 * m);
save_figure(fh, outdir, 'Fig8_correction_overhead', 3.17, 2.4);
end

% ======================================================================================
function T = read_csv(f)
% Read a CSV file with a header line into a struct of columns (numeric where possible).
txt = fileread(f);
lines = regexp(txt, '\r?\n', 'split');
lines = lines(~cellfun(@isempty, strtrim(lines)) & ~strncmp(lines, '#', 1));
hdr = strsplit(strtrim(lines{1}), ',');
n = numel(lines) - 1; C = cell(n, numel(hdr));
for r = 1:n
  v = strsplit(strtrim(lines{r + 1}), ',');
  v(end+1:numel(hdr)) = {''};
  C(r, :) = v(1:numel(hdr));
end
T = struct();
for k = 1:numel(hdr)
  v = str2double(C(:, k));
  if all(~isnan(v) | strcmp(C(:, k), '') | strcmpi(C(:, k), 'NaN'))
    T.(hdr{k}) = v;
  else
    T.(hdr{k}) = C(:, k);
  end
end
end

function tf = is_absolute(p)
% True for absolute paths (C:\..., \\server\..., /...).
tf = (numel(p) >= 2 && p(2) == ':') || any(strncmp(p, {'/', '\\'}, 1));
end

function fh = new_figure(w, h)
fh = figure('Visible', 'off', 'Units', 'inches', 'Position', [1 1 w h], 'Color', 'w');
end

function style_axes(ax, xs, ys)
set(ax, 'XScale', xs, 'YScale', ys, 'FontName', 'Times', 'FontSize', 7, 'Box', 'on', ...
        'XGrid', 'on', 'YGrid', 'on', 'GridAlpha', 0.15, 'LineWidth', 0.6);
end

function save_figure(fh, outdir, name, w, h)
set(fh, 'PaperUnits', 'inches', 'PaperSize', [w h], 'PaperPosition', [0 0 w h]);
print(fh, fullfile(outdir, [name '.pdf']), '-dpdf');
print(fh, fullfile(outdir, [name '.png']), '-dpng', '-r300');
close(fh);
fprintf('  -> %s.pdf / .png\n', name);
end
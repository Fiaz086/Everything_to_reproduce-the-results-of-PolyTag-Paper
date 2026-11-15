%RUN_08_PROTECTION  Minimum number of authenticated devices (buses) such that no
%   stealth attack a = Hc exists after any k devices are compromised (DC model).
%   Exact cutting-plane ILP (intlinprog in MATLAB, GLPK in Octave) with seed cuts,
%   lazy null-space cuts and a greedy repair step that gives a feasible solution
%   (upper bound) at every iteration. Reports [LB, UB]; LB = UB means proven optimal.
%   Time limits: tlimit (whole cutting-plane loop, s) and solve_tlimit (each ILP
%   solve, s). For runs without time limits set  tlimit = Inf; solve_tlimit = Inf;
%   before calling this script.
%   Reference platform (paper, Section IX): HP laptop, Intel Core i7-1255U (10 cores),
%   GNU Octave 8.4.0, MATPOWER 8.1.1-dev. The CPU actually used is
%   recorded in results/00_platform.txt by platform_info (called from run_all).
setup_paths;
if ~exist('cases','var'), cases = {'case14','case30','case118','case300'}; end
if ~exist('csvmode','var'), csvmode = 'w'; end
if ~exist('tlimit','var'), tlimit = 900; end
if ~exist('solve_tlimit','var'), solve_tlimit = 60; end
isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;
if ~isOctave   % MATLAB: intlinprog (Optimization Toolbox)
  ilpopts = optimoptions('intlinprog', 'Display', 'off', 'MaxTime', solve_tlimit);
end
fid = fopen('results/08_protection.csv', csvmode);
if csvmode == 'w'
  fprintf(fid, 'system,n_devices,k,status,lower_bound,upper_bound,greedy_disjoint_bound,cuts_total,iterations,solve_time_s\n');
end
for c = 1:numel(cases)
  [H, own, N] = dc_model(cases{c}); nx = size(H, 2);
  Gdev = cell(N, 1);
  for j = 1:N, Hj = H(own == j, :); Gdev{j} = full(Hj' * Hj); end
  if ~exist('klist','var'), klist = 0:2; end
  for k = klist
    tic; it = 0;
    % seed cuts (valid for every feasible Y): attack c = e_i is seen only by the
    % devices T_i whose rows touch state i; any k of them may be compromised,
    % so at least k+1 of them must be authenticated.
    A = zeros(nx, N); bseed = (k + 1) * ones(nx, 1);
    for i = 1:nx
      Ti = unique(own(abs(H(:, i)) > 0)); A(i, Ti) = 1;
      bseed(i) = min(bseed(i), numel(Ti));
    end
    status = 'optimal'; LB = NaN; UB = inf;
    [okAll, Cbad] = robust_check(Gdev, ones(N,1), k, nx);
    if ~okAll
      status = sprintf('infeasible (compromising devices %s isolates a state)', mat2str(Cbad));
    else
      while true
        it = it + 1;
        bvec = [bseed; ones(size(A,1)-nx,1)];
        if isOctave
          [y, ~, err] = glpk(ones(N,1), A, bvec, zeros(N,1), ones(N,1), ...
                             repmat('L', 1, size(A,1)), repmat('I', 1, N), 1, struct('msglev', 0, 'tmlim', min(solve_tlimit*1000, 2^31-1)));
          if err ~= 0, status = sprintf('glpk error %d', err); break; end
          y = round(y);
          lbIt = sum(y);   % valid only if glpk reached optimality (status not checked)
        else
          % A*y >= b  is written as  -A*y <= -b  for intlinprog
          [y, fval, exitflag, output] = intlinprog(ones(N,1), 1:N, -A, -bvec, [], [], ...
                                                   zeros(N,1), ones(N,1), ilpopts);
          if exitflag <= 0 || isempty(y)
            status = sprintf('intlinprog exit flag %d', exitflag); break;
          end
          y = round(y);
          if exitflag == 1
            lbIt = sum(y);                                     % proven optimum of the relaxation
          else
            lbIt = ceil(fval - output.absolutegap - 1e-6);     % proven bound when stopped early
          end
        end
        LB = max([LB, lbIt]);
        [ok, Cs, cv] = robust_check(Gdev, y, k, nx);
        if ok, UB = sum(y); break; end
        % greedy repair -> feasible solution -> upper bound
        yr = y; okr = ok; Cr = Cs; cr = cv;
        while ~okr
          added = false;
          for col = 1:size(cr, 2)
            a = H * cr(:, col); rows = abs(a) > 1e-8 * max(abs(a));
            cand = setdiff(unique(own(rows)), [Cr(:); find(yr)]);
            if isempty(cand), continue; end
            cnt = arrayfun(@(j) sum(own(rows) == j), cand);
            [~, jb] = max(cnt); yr(cand(jb)) = 1; added = true; break;
          end
          if ~added, yr(:) = 1; end
          [okr, Cr, cr] = robust_check(Gdev, yr, k, nx);
        end
        UB = min(UB, sum(yr));
        % lazy cuts: some authenticated, uncompromised device must see H*c
        for col = 1:size(cv, 2)
          a = H * cv(:, col); rows = abs(a) > 1e-8 * max(abs(a));
          devs = setdiff(unique(own(rows)), Cs);
          cut = zeros(1, N); cut(devs) = 1; A = [A; cut]; %#ok
        end
        fprintf('  it %d: LB %d UB %d cuts %d (%.0f s)\n', it, LB, UB, size(A,1), toc);
        if LB >= UB, break; end
        if toc > tlimit, status = sprintf('time limit %d s', tlimit); break; end
      end
    end
    if strcmp(status, 'optimal') && LB < UB
      status = sprintf('feasible, gap %g-%g (an ILP solve hit its time limit)', LB, UB);
    end
    tsolve = toc;
    % greedy disjoint bases: k+1 disjoint device sets, each of full rank
    used = false(N, 1); total = 0; gfeas = true;
    for b = 1:k+1
      G = zeros(nx); nS = 0;
      while rank(G) < nx
        cand = find(~used); gain = -inf; jbest = 0; r0 = rank(G);
        for j = cand'
          g = rank(G + Gdev{j}); if g > gain, gain = g; jbest = j; end
        end
        if isempty(cand) || gain <= r0, gfeas = false; break; end
        used(jbest) = true; nS = nS + 1; G = G + Gdev{jbest};
      end
      if ~gfeas, break; end
      total = total + nS;
    end
    if ~gfeas, total = NaN; end
    fprintf(fid, '%s,%d,%d,"%s",%g,%g,%g,%d,%d,%.2f\n', cases{c}, N, k, status, LB, UB, total, size(A,1), it, tsolve);
    fprintf('%s N=%d k=%d: %s  LB %g UB %g  greedy-disjoint %g  cuts %d  (%.1f s)\n', cases{c}, N, k, status, LB, UB, total, size(A,1), tsolve);
  end
end
fclose(fid);

function D = gen_dataset(casename, nDays, seed)
%GEN_DATASET  Hourly AC power-flow snapshots with seasonal load variation.
%   D = GEN_DATASET('case118', 365, 1) runs 24*nDays Newton power flows
%   (MATPOWER newtonpf) and returns noiseless measurement vectors D.Z (m x T,
%   MW/Mvar), complex voltages D.V (n x T) and the network data needed later.
%   Each bus load is scaled by an independent factor drawn uniformly from the
%   hourly seasonal band (seasonal_profiles); dispatchable generation is
%   scaled by the mean factor and the slack bus absorbs the rest.
if nargin < 3, seed = 1; end
rng(seed, 'twister');
define_constants;
mpc = ext2int(loadcase(casename));
[baseMVA, bus, gen, branch] = deal(mpc.baseMVA, mpc.bus, mpc.gen, mpc.branch);
[ref, pv, pq] = bustypes(bus, gen);
[Ybus, Yf, Yt] = makeYbus(baseMVA, bus, branch);
n = size(bus,1); L = size(branch,1); m = 2*n + 4*L;
S = seasonal_profiles();
mpopt = mpoption('verbose', 0, 'out.all', 0);

on = find(gen(:, GEN_STATUS) > 0); gbus = gen(on, GEN_BUS);
V0 = bus(:, VM) .* exp(1j * pi/180 * bus(:, VA));
V0(gbus) = gen(on, VG) ./ abs(V0(gbus)) .* V0(gbus);

T = 24 * nDays;
D.Z = zeros(m, T); D.V = complex(zeros(n, T)); D.ok = false(1, T);
D.season = zeros(1, T); D.hour = zeros(1, T);
names = {'winter','spring','summer','fall'};
for day = 1:nDays
  doy = round(day * 365 / nDays);                 % spread days over the year
  mon = ceil(doy / 30.42);
  if mon == 12 || mon <= 2, s = 1; elseif mon <= 5, s = 2; elseif mon <= 8, s = 3; else, s = 4; end
  band = S.(names{s});
  for h = 1:24
    k = (day-1)*24 + h;
    u = (band(h,1) + rand(n,1) * (band(h,2) - band(h,1))) / 100;
    b2 = bus; b2(:, PD) = bus(:, PD) .* u; b2(:, QD) = bus(:, QD) .* u;
    g2 = gen; g2(:, PG) = gen(:, PG) * mean(u);
    Sfun = @(Vm) makeSbus(baseMVA, b2, g2, mpopt, Vm);
    [V, conv] = newtonpf(Ybus, Sfun, V0, ref, pv, pq, mpopt);
    D.ok(k) = conv; D.season(k) = s; D.hour(k) = h;
    if conv
      D.V(:, k) = V;
      D.Z(:, k) = meas_model(Ybus, Yf, Yt, branch, V, ref, baseMVA);
    end
  end
end
D.casename = casename; D.n = n; D.L = L; D.m = m; D.ref = ref;
D.baseMVA = baseMVA; D.bus = bus; D.branch = branch; D.Ybus = Ybus; D.Yf = Yf; D.Yt = Yt;
end

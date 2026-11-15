function [H, own, n_dev] = dc_model(casename)
%DC_MODEL  DC measurement Jacobian (P injections, P from-flows, P to-flows; p.u.)
%   with the reference angle removed, and the owning device (bus) of every row.
define_constants;
mpc = ext2int(loadcase(casename));
[Bbus, Bf] = makeBdc(mpc.baseMVA, mpc.bus, mpc.branch);
ref = find(mpc.bus(:, BUS_TYPE) == REF); n = size(mpc.bus, 1);
f = mpc.branch(:, F_BUS); t = mpc.branch(:, T_BUS);
H = [Bbus; Bf; -Bf]; H(:, ref) = [];
own = [(1:n)'; f; t];
n_dev = n;
end

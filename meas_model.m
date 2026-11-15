function [z, H] = meas_model(Ybus, Yf, Yt, branch, V, ref, baseMVA)
%MEAS_MODEL  AC measurement vector and its Jacobian.
%   z = [Pinj; Qinj; Pf; Qf; Pt; Qt] in MW / Mvar (m = 2n + 4L).
%   H = dz/d[Va(non-ref); Vm] (MW per rad, MW per p.u.), m x (2n-1).
f = branch(:,1); t = branch(:,2);
Sinj = V .* conj(Ybus * V);
Sf = V(f) .* conj(Yf * V);
St = V(t) .* conj(Yt * V);
z = baseMVA * [real(Sinj); imag(Sinj); real(Sf); imag(Sf); real(St); imag(St)];
if nargout > 1
  [dS_dVa, dS_dVm] = dSbus_dV(Ybus, V);
  [dSf_dVa, dSf_dVm, dSt_dVa, dSt_dVm] = dSbr_dV(branch, Yf, Yt, V);
  n = numel(V); nr = setdiff(1:n, ref);
  H = baseMVA * [real(dS_dVa(:,nr)) real(dS_dVm); imag(dS_dVa(:,nr)) imag(dS_dVm); ...
                 real(dSf_dVa(:,nr)) real(dSf_dVm); imag(dSf_dVa(:,nr)) imag(dSf_dVm); ...
                 real(dSt_dVa(:,nr)) real(dSt_dVm); imag(dSt_dVa(:,nr)) imag(dSt_dVm)];
  % H is returned sparse (memory: the 300-bus system has m = 2244)
end
end

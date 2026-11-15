function out = hmac_sha256(key, msg)
%HMAC_SHA256  HMAC-SHA256 (RFC 2104) returning 32 uint8 bytes.
%   Uses Java's javax.crypto in MATLAB (as in the RP-VDVM code) and Octave's
%   built-in hash() otherwise.
if exist('OCTAVE_VERSION', 'builtin') == 0
  keySpec = javax.crypto.spec.SecretKeySpec(uint8(key), 'HmacSHA256');
  mac = javax.crypto.Mac.getInstance('HmacSHA256'); mac.init(keySpec);
  out = typecast(mac.doFinal(uint8(msg)), 'uint8'); out = out(:)';
  return;
end
B = 64; k = uint8(key);
if numel(k) > B, k = sha_bytes(k); end
k = [k, zeros(1, B - numel(k), 'uint8')];
inner = sha_bytes([bitxor(k, uint8(54)), uint8(msg)]);
out = sha_bytes([bitxor(k, uint8(92)), inner]);
end
function d = sha_bytes(b)
h = hash('sha256', char(b));
d = uint8(hex2dec(reshape(h, 2, [])'))';
end

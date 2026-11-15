function info = platform_info(outfile)
%PLATFORM_INFO  Record the machine on which the experiments are run.
%   INFO = PLATFORM_INFO() returns a struct with the detected CPU model,
%   operating system and software versions. PLATFORM_INFO(OUTFILE) also
%   writes them, together with the reference platform stated in the paper,
%   to OUTFILE (run_all uses results/00_platform.txt).
%
%   Reference platform of the paper (Section IX): HP laptop with an
%   Intel Core i7-1255U processor (10 cores); GNU Octave 8.4.0 with
%   MATPOWER 8.1.1-dev; C code compiled with GCC (-O2 -march=native)
%   against OpenSSL 3. All timings are single-threaded (one core).
info.reference = 'HP laptop, Intel Core i7-1255U (10 cores)';
info.cpu = detect_cpu();
info.os = computer();
if exist('OCTAVE_VERSION', 'builtin'), info.engine = ['GNU Octave ' OCTAVE_VERSION];
else, info.engine = ['MATLAB ' version]; end
try, info.matpower = mpver; catch, info.matpower = 'not found'; end
info.date = datestr(now, 'yyyy-mm-dd HH:MM:SS');
if nargin > 0
  fid = fopen(outfile, 'w');
  fprintf(fid, 'reference_platform_in_paper: %s\n', info.reference);
  fprintf(fid, 'detected_cpu: %s\n', info.cpu);
  fprintf(fid, 'os: %s\nengine: %s\nmatpower: %s\nrun_started: %s\n', info.os, info.engine, info.matpower, info.date);
  fclose(fid);
end
fprintf('Platform: %s | reference in paper: %s\n', info.cpu, info.reference);
end

function cpu = detect_cpu()
cpu = 'unknown';
try
  if ispc
    [st, out] = system('powershell -NoProfile -Command "(Get-CimInstance Win32_Processor).Name"');
    if st ~= 0 || isempty(strtrim(out)), [st, out] = system('wmic cpu get name'); out = regexprep(out, '^\s*Name\s*', ''); end
    if st == 0 && ~isempty(strtrim(out)), cpu = strtrim(out); else, cpu = getenv('PROCESSOR_IDENTIFIER'); end
  elseif ismac
    [st, out] = system('sysctl -n machdep.cpu.brand_string');
    if st == 0, cpu = strtrim(out); end
  else
    txt = fileread('/proc/cpuinfo');
    tok = regexp(txt, 'model name\s*:\s*([^\n]*)', 'tokens', 'once');
    if ~isempty(tok), cpu = strtrim(tok{1}); end
  end
catch
end
end

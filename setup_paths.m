%SETUP_PATHS  Add MATPOWER to the path and create the output folders.
%   Edit ROOT to the folder where MATPOWER is installed. If MATPOWER was
%   installed with install_matpower and saved on the MATLAB path, this
%   script still works (adding a path twice is harmless).
root = 'C:/path/to/matpower';   % <-- edit: folder where MATPOWER is installed
addpath(fullfile(root,'lib')); addpath(fullfile(root,'data'));
addpath(fullfile(root,'mips','lib')); addpath(fullfile(root,'mp-opt-model','lib')); addpath(fullfile(root,'mptest','lib'));
% Output folders in the CURRENT folder. The full path is needed: exist('data','dir')
% would also find MATPOWER's own data folder on the MATLAB path and skip mkdir.
if exist(fullfile(pwd, 'results'), 'dir') ~= 7, mkdir(fullfile(pwd, 'results')); end
if exist(fullfile(pwd, 'data'), 'dir') ~= 7, mkdir(fullfile(pwd, 'data')); end

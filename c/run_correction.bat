@echo off
rem Keyed-syndrome correction in C over GF(2^127-1): correctness check and timing (Table 12).
rem Run run_13_correction in MATLAB first, so the cross-check file exists. Double-click this file.
cd /d "%~dp0"
if not exist "..\results" mkdir "..\results"
echo Running the correction benchmark. This takes a few minutes.
echo Keep the laptop plugged in and close other programs.
echo.
correction127.exe > "..\results\13_correction_c.csv" 2> "..\results\13_correction_c_platform.txt"
type "..\results\13_correction_c_platform.txt"
echo.
echo Done. Please send results\13_correction_c.csv and results\13_correction_c_platform.txt
pause

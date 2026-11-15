@echo off
rem Runs the PolyTag timing benchmark (Table 8, Fig. 6) on Windows. Double-click this file.
cd /d "%~dp0"
if not exist "..\results" mkdir "..\results"
echo Running the PolyTag benchmark. This takes a few minutes.
echo Keep the laptop plugged in and close other programs.
echo.
bench.exe > "..\results\12_bench.csv" 2> "..\results\12_bench_platform.txt"
type "..\results\12_bench_platform.txt"
echo.
echo Done. Please send results\12_bench.csv and results\12_bench_platform.txt
pause

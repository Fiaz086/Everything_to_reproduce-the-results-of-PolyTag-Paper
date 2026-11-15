#!/bin/bash
# Build and run the PolyTag timing benchmark (Table 8, Fig. 6) in WSL/Ubuntu or Linux.
# Usage, from this folder:  bash run_bench.sh
set -e
cd "$(dirname "$0")"
echo "1/3 Installing compiler and OpenSSL (asks for your Ubuntu password once)..."
sudo apt-get update -qq && sudo apt-get install -y -qq build-essential libssl-dev
echo "2/3 Compiling..."
gcc -O2 -march=native -o bench bench.c -lcrypto
mkdir -p ../results
echo "3/3 Running the benchmark (about a minute; keep the laptop plugged in)..."
./bench > ../results/12_bench.csv 2> ../results/12_bench_platform.txt
echo
cat ../results/12_bench_platform.txt
echo
echo "Done. Send results/12_bench.csv and results/12_bench_platform.txt."
